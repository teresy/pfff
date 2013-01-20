(* Yoann Padioleau
 * 
 * Copyright (C) 2012 Facebook
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public License
 * version 2.1 as published by the Free Software Foundation, with the
 * special exception on linking described in file license.txt.
 * 
 * This library is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the file
 * license.txt for more details.
 *)
open Common
(* floats are the norm in graphics *)
open Common.ArithFloatInfix

open Figures

open Model3
module M = Model3
module Ctl = Controller3

module E = Database_code
module DM = Dependencies_matrix_code

module CairoH = Cairo_helpers3

(*****************************************************************************)
(* Prelude *)
(*****************************************************************************)

(*****************************************************************************)
(* Helpers *)
(*****************************************************************************)

(* less: have a draw_labels.ml ? *) 

(* similar to highlight_code.ml *)
let color_of_node (_, kind) =
  match kind with
  | E.Function -> "gold"
  (* less: different color for interfaces and traits? *)
  | E.Class _ -> "coral"
  | E.Module -> "chocolate"
  | E.Package -> "chocolate"
  | E.Type -> "YellowGreen"
  | E.Constant -> "pink"
  | E.Global -> "cyan"
  | E.Macro -> "pink1"
  | E.Exception -> "orchid"
  | E.TopStmts -> raise Todo

  | E.Method _ -> "gold3"
  | E.Field -> "MediumPurple1"
  | E.ClassConstant -> "pink3"
  | E.Constructor -> "pink3"

  | E.Other s -> raise Todo

  | E.Dir -> "SteelBlue2"
  | E.MultiDirs -> "SteelBlue3"
  | E.File -> "wheat"

(* we often keep fully qualified names in the graph_code to avoid
 * ambiguities between entities, but in code_graph we prefer to
 * display short names as the parents already contain the
 * information.
 *)
let txt_of_node (s, kind) = 
  match kind with
  | E.Dir | E.File | E.MultiDirs -> Common.basename s
  | E.Package | E.Module
  | E.Class _ 
  | E.Field | E.Constructor | E.Method _  | E.ClassConstant
  | E.Function | E.Type | E.Constant | E.Global
  | E.Exception 
    ->
      let xs = Common.split "[.]" s in
      Common.list_last xs
  | _ -> s

(* todo: style/font_of_node_kind? so put in bold directories *)

let line_width_of_depth l d =
  let h = l.height_cell in
  match d with
  | 0 -> h / 8.
  | 1 -> h / 20.
  | 2 -> h / 40.
  | _ -> h / 80.

let line_color_of_depth d =
  match d with
  | 0 -> "wheat"
  | 1 -> "grey80"
  | 2 -> "grey65"
  | 3 -> "grey50"
  | _ -> "grey30"

(*****************************************************************************)
(* Matrix Coord -> XY Coord  *)
(*****************************************************************************)

let rect_of_column j l =
  let x = (float_of_int j) * l.width_cell + l.x_start_matrix_left in
  let y = l.y_start_matrix_up in
  { p = { x; y };
    q = { x = x + l.width_cell; y = l.y_end_matrix_down }
  }

let rect_of_line i l =
  let x = l.x_start_matrix_left in
  let y = (float_of_int i) * l.height_cell + l.y_start_matrix_up in
  { p = { x; y };
    q = { x = l.x_end_matrix_right; y = y + l.height_cell }
  }

let rect_of_label_left i l =
  let x = 0.0 in
  let y = (float_of_int i) * l.height_cell + l.y_start_matrix_up in
  { p = { x = x; y = y; };
    q = { x = l.x_start_matrix_left; y = y + l.height_cell };
  }
 

(*****************************************************************************)
(* Drawing helpers *)
(*****************************************************************************)

let draw_cells cr w ~interactive_regions =
  let l = M.layout_of_w w in

  for i = 0 to l.nb_elts -.. 1 do
    for j = 0 to l.nb_elts -.. 1 do
      (* the matrix is accessed as matrix.(row).(col), but here y corresponds
       * to the row, and x to the column, hence the association of j to x
       * and i to y.
       *)
      let x = (float_of_int j) * l.width_cell + l.x_start_matrix_left in
      let y = (float_of_int i) * l.height_cell + l.y_start_matrix_up in

      let rect = { 
        p = { x = x; y = y; };
        q = { x = x + l.width_cell; y = y + l.height_cell };
      } in
      Common.push2 (Cell (i, j), rect) interactive_regions;
      
      (* less: could also display intra dependencies *)
      if i = j then
        (* todo: heatmap? *)
        CairoH.fill_rectangle_xywh ~cr ~x ~y ~w:l.width_cell ~h:l.height_cell
          ~color:"wheat" ()
      else begin
        (* old: this is now done in draw_left_rows
         *  let _line_width = line_width_of_depth l depth in
         *  CairoH.draw_rectangle ~cr ~line_width ~color:"wheat" rect; 
         *)
        let n = w.m.DM.matrix.(i).(j) in
        if n > 0 then begin
          let txt = string_of_int n in
          let font_size = 
            match n with
            | _ when n <= 10 -> 
                l.width_cell / 2.
            | _ ->
                l.width_cell / (float_of_int (String.length txt))
          in
          CairoH.set_font_size cr font_size;
          (* todo: optimize? *)
          let extent = CairoH.text_extents cr txt in
          let tw = extent.Cairo.text_width in
          let th = extent.Cairo.text_height in
          
          let x = x + (l.width_cell / 2.) - (tw / 2.0) in
          let y = y + (l.height_cell / 2.) + (th / 2.0) in
          Cairo.move_to cr x y;
          CairoH.show_text cr txt;
        end;
      end
    done
  done;
  ()

let draw_left_tree cr w ~interactive_regions =
  let l = M.layout_of_w w in
  let font_size_default = min (l.height_cell/1.5) (l.x_start_matrix_left/10.) in
  CairoH.set_font_size cr font_size_default;


  let i = ref 0 in
  let rec aux depth tree =
    match tree with
    (* a leaf *)
    | DM.Node (node, []) ->
        (* draw box around label *)
        let x = float_of_int depth * l.width_vertical_label in
        let y = (float_of_int !i) * l.height_cell + l.y_start_matrix_up in
        let rect = { 
          p = { x = x; y = y; };
          q = { x = l.x_start_matrix_left; y = y + l.height_cell };
        } in
        let line_width = line_width_of_depth l depth in
        let color = line_color_of_depth depth in
        CairoH.draw_rectangle ~cr ~line_width ~color rect;

        Common.push2 (Row !i, rect) interactive_regions;

        (* draw horizontal lines around cells *)
        let rect2 = {
          p = { x = l.x_start_matrix_left; y = y; };
          q = { x = l.x_end_matrix_right; y = y + l.height_cell };
        } in
        CairoH.draw_rectangle ~cr ~line_width ~color rect2;
       
        (* draw vertical lines around cells *)
        let x' = (float_of_int !i) * l.width_cell + l.x_start_matrix_left in
        let y'  = l.y_start_matrix_up in
        let rect3 = {
          p = { x = x'; y = y'; };
          q = { x = x' + l.width_cell; y = l.y_end_matrix_down};
        } in
        CairoH.draw_rectangle ~cr ~line_width ~color rect3;

        (* old: let node = Hashtbl.find w.m.DM.i_to_name i in *)
        let color = color_of_node node in
        let txt = txt_of_node node in
        CairoH.set_source_color cr color ();
        CairoH.set_font_size cr font_size_default;
        let extent = CairoH.text_extents cr txt in
        let w = extent.Cairo.text_width in
        let width_for_label = l.x_start_matrix_left - x in
        (* todo: could try different settings until it works? like in cm? *)
        let font_size_final =
          if w > width_for_label 
          then (font_size_default / (w / width_for_label))
          else font_size_default
        in
        CairoH.set_font_size cr font_size_final;

        (* align text on the left *)
        let extent = CairoH.text_extents cr txt in
        let th = extent.Cairo.text_height in
        Cairo.move_to cr (x + 0.002) (y + (l.height_cell /2.) + (th / 2.0));
        CairoH.show_text cr txt;
        incr i

    (* a node, draw the label vertically *)
    | DM.Node (node, xs) ->
        let x = float_of_int depth * l.width_vertical_label in
        let y = (float_of_int !i) * l.height_cell + l.y_start_matrix_up in
        let n = float_of_int (List.length (DM.final_nodes_of_tree tree)) in
        let rect = {
          p = { x; y; };
          q = { x = x + l.width_vertical_label; y = y + n * l.height_cell};
        } in

        let line_width = line_width_of_depth l depth in
        CairoH.draw_rectangle ~cr ~line_width ~color:"SteelBlue2" rect;
        (* todo? push2 ?? interactive_regions *)

        let color = color_of_node node in
        let txt = txt_of_node node in
        CairoH.set_source_color cr color ();
        let font_size_default = 
          min (l.width_vertical_label/1.5) ((n * l.height_cell) /10.) in

        CairoH.set_font_size cr font_size_default;
        let extent = CairoH.text_extents cr txt in
        let w = extent.Cairo.text_width in

        let width_for_label = n * l.height_cell in
        (* todo: could try different settings until it works? like in cm? *)
        let font_size_final =
          if w > width_for_label 
          then (font_size_default / (w / width_for_label))
          else font_size_default
        in
        CairoH.set_font_size cr font_size_final;

        (* center the text *)
        let extent = CairoH.text_extents cr txt in
        let th = extent.Cairo.text_height in
        let tw = extent.Cairo.text_width in
        let angle = -. (pi / 2.) in
        Cairo.move_to cr 
          ((x + l.width_vertical_label / 2.) + (th / 2.0))
          (y + ((n * l.height_cell) /2.) + (tw / 2.0));
        Cairo.rotate cr ~angle;
        CairoH.show_text cr txt;
        Cairo.rotate cr ~angle:(-. angle);
        
        xs +> List.iter (aux (depth +.. 1))
  in
  (* use dm.config, not w.config which is not necessaraly ordered *)
  let config = w.m.DM.config in
  (match config with
  | DM.Node (_root, xs) -> xs +> List.iter (aux 0)
  )

let draw_up_columns cr w ~interactive_regions =
  let l = M.layout_of_w w in

  (* peh because it exercises the spectrum of high letters *)
  let extent = CairoH.text_extents cr "peh" in
  let _base_tw = extent.Cairo.text_width / 3. in
  let th = extent.Cairo.text_height in

  (* not -.. 1, cos we draw lines here, not rectangles *)
  for j = 0 to l.nb_elts do
    let x = (float_of_int j) * l.width_cell + l.x_start_matrix_left in
    let y = l.y_start_matrix_up in
    let rect = {
      (* fake rectangle *)
      p = { x = x; y = 0. };
      q = { x = x + l.width_cell; y = l.y_start_matrix_up };
    } in
    Common.push2 (Column j, rect) interactive_regions;

    CairoH.set_source_color ~cr ~color:"wheat" ();
    Cairo.move_to cr x y;
    (* because of the xy_ratio, this actually does not do a 45 deg line.
     * old: Cairo.line_to cr (x + (y_start_matrix_up / atan (pi / 4.)))  0.; 
     *)
    Cairo.line_to cr (x + (l.y_start_matrix_up / atan (pi / 2.8)))  0.; 
    Cairo.stroke cr;

    if j < l.nb_elts then begin
      let node = w.m.DM.i_to_name.(j) in
      Cairo.move_to cr (x + (l.width_cell / 2.0) + (th / 2.0)) (y - 0.001);
      let angle = -. (pi / 4.) in
      Cairo.rotate cr ~angle:angle;
      let color = color_of_node node in
      let txt = txt_of_node node in
      CairoH.set_source_color cr color ();
      CairoH.show_text cr txt;
      Cairo.rotate cr ~angle:(-. angle);
    end;
  done;
  ()

(*****************************************************************************)
(* Semantic overlays *)
(*****************************************************************************)

let highlight_dead_columns cr w =
  let l = M.layout_of_w w in
  let mat = w.m.DM.matrix in
  for j = 0 to Array.length mat -.. 1 do
    if DM.is_dead_column j w.m
    then begin
      CairoH.fill_rectangle ~cr ~alpha:0.3 ~color:"red" 
        (rect_of_column j l);
      CairoH.fill_rectangle ~cr ~alpha:0.3 ~color:"red" 
        (rect_of_label_left j l)
    end
  done

let highlight_dead_lines cr w =
  let l = M.layout_of_w w in
  let mat = w.m.DM.matrix in
  for i = 0 to Array.length mat -.. 1 do
    if DM.is_dead_line i w.m
    then begin
      CairoH.fill_rectangle ~cr ~alpha:0.3 ~color:"green" 
        (rect_of_line i l);
      CairoH.fill_rectangle ~cr ~alpha:0.3 ~color:"green" 
        (rect_of_label_left i l)
    end
  done


let highlight_internal_helpers cr w =
  let l = M.layout_of_w w in
  let mat = w.m.DM.matrix in
  for i = 0 to Array.length mat -.. 1 do
    if DM.is_internal_helper i w.m
    then begin
      CairoH.fill_rectangle ~cr ~alpha:0.1 ~color:"blue" 
        (rect_of_label_left i l)
    end
  done

(*****************************************************************************)
(* Drawing entry point *)
(*****************************************************************************)

(* assumes cr is setup with uniform coordinate system *)
let draw_matrix cr w =
  (* clear the screen *)
  CairoH.fill_rectangle_xywh ~cr ~x:0.0 ~y:0.0 ~w:xy_ratio ~h:1.0 
    ~color:"DarkSlateGray" ();

  let l = M.layout_of_w w in

  (* draw matrix enclosing rectangle *)
  CairoH.draw_rectangle ~cr ~line_width:0.001 ~color:"wheat"
    { p = { x = l.x_start_matrix_left; y = l.y_start_matrix_up };
      q = { x = l.x_end_matrix_right; y = 1.0 };
    };
  Cairo.select_font_face cr "serif"
    Cairo.FONT_SLANT_NORMAL Cairo.FONT_WEIGHT_BOLD;

  let interactive_regions = ref [] in

  draw_cells      cr w ~interactive_regions;
  draw_left_tree  cr w ~interactive_regions;
  draw_up_columns cr w ~interactive_regions;

  (* highlight_dead_lines cr w; *)
  highlight_dead_columns cr w;
  highlight_internal_helpers cr w;

  (* todo: could start from the config and mark all children of PB too *)
  let nodes_pb = w.m.DM.i_to_name +> Array.to_list +> List.filter (fun n ->
    fst n = "PB"
  ) in
  let nodes_dots = w.m.DM.i_to_name +> Array.to_list +> List.filter (fun n ->
    snd n = E.MultiDirs
  ) in
  let score_up   = DM.score_upper_triangle w.m [] in
  let score_down = DM.score_downer_triangle w.m [] in

  let biggest_offenders =
    DM.score_upper_triangle_nodes w.m 
    +> Common.sort_by_val_highfirst
    +> Common.take_safe 4
  in
  let nodes_major = biggest_offenders +> List.map fst in
    
  !Ctl._label_settext 
    (spf "#backward deps = %d (%.2f%%), - PB = %d, - ... = %d, - biggest = %d" 
       score_up
       (Common.pourcent_float score_up (score_up +.. score_down))
       (DM.score_upper_triangle w.m nodes_pb)
       (DM.score_upper_triangle w.m (nodes_pb $+$ nodes_dots))
       (DM.score_upper_triangle w.m (nodes_pb $+$ nodes_dots $+$ nodes_major))
    );

  w.interactive_regions <- !interactive_regions;
  ()

(*****************************************************************************)
(* Painting entry point *)
(*****************************************************************************)

(* paint() creates the cairo context and adjusts the scaling if needed
 * and then calls the 'draw' functions.
 *)
let paint w =
  let cr = Cairo.create w.base in
  scale_coordinate_system cr w;
  draw_matrix cr w;
  !Ctl._refresh_drawing_area ();
  ()

(*****************************************************************************)
(* Events *)
(*****************************************************************************)

let recompute_matrix w =
  let config = M.config_of_path w.path w.model in
  let m, gopti = 
    Common.profile_code2 "Model.building matrix" (fun () -> 
      Dependencies_matrix_code.build config 
        (Some w.model.constraints) w.model.gopti
    )
  in
  w.model.gopti <- gopti;
  !Ctl._set_title (DM.string_of_config_path w.path);
  w.m <- m;
  paint w;
  ()

let add_path x path = path ++ [x]

let button_action da w ev =
  let (x, y) = GdkEvent.Button.x ev, GdkEvent.Button.y ev in
  let pt = { Cairo. x = x; y = y } in
  pr2 (spf "button action device coord: %f, %f" x y);

  let cr = Cairo.create w.overlay in
  M.scale_coordinate_system cr w;

  let pt2 = Cairo.device_to_user cr pt in
  let (x, y) = (pt2.Cairo.x, pt2.Cairo.y) in
  pr2 (spf "button action user coord: %f, %f" x y);

  (match M.find_region_at_user_point w ~x ~y with
  | None -> false
  | Some x ->
      (match x with
      | Row i -> 
            (match GdkEvent.get_type ev, GdkEvent.Button.button ev with
            | `TWO_BUTTON_PRESS, 1 ->
                pr2 (spf "double clicking on row i");
                let node = w.m.DM.i_to_name.(i) in
                w.path <- add_path (DM.Expand node) w.path;
                recompute_matrix w;
                true
            | `BUTTON_PRESS, 3 ->
                pr2 (spf "right clicking on row i");
                let node = w.m.DM.i_to_name.(i) in
                w.path <- add_path (DM.Focus (node, DM.DepsOut)) w.path;
                recompute_matrix w;
                true

            | `BUTTON_RELEASE, _ |  _ ->
                false
            )
      | Cell (i, j) -> 
            (match GdkEvent.get_type ev, GdkEvent.Button.button ev with
            | `BUTTON_PRESS, 1 ->
                pr2 (spf "clicking on cell (%d, %d)" i j);
                let deps = 
                  DM.explain_cell_list_use_edges  (i, j) w.m w.model.gopti in
                let xs = Common.take_safe 1000 deps in
                let grouped_deps = 
                  Graph_code.group_edges_by_files_edges xs 
                    w.model.g_deprecated in
                let str = 
                  grouped_deps +> List.map (fun ((f1, f2), deps) ->
                    let final_file f =
                      try 
                        Common.filename_without_leading_path w.model.root f
                      with Failure _ -> f
                    in
                    let f1 = final_file f1 in
                    let f2 = final_file f2 in
                    spf "%s --> %s (%d)\n" f1 f2 (List.length deps) ^
                    (Common.take_safe 2 deps +> List.map (fun (n1, n2) ->
                      spf "            %s --> %s" 
                      (Graph_code.string_of_node n1)  
                      (Graph_code.string_of_node n2)
                     ) +> Common.join "\n"
                    )
                  ) +> Common.join "\n"
                in
                pr2 str;
                Gui.dialog_text ~text:str ~title:"Cell explaination";
                true

            | `BUTTON_PRESS, 3 ->
                pr2 (spf "right clicking on cell (%d, %d)" i j);
                if i = j
                then begin
                  let node = w.m.DM.i_to_name.(j) in
                  w.path <- add_path (DM.Focus (node, DM.DepsInOut)) w.path;
                  recompute_matrix w;
                  true
                end else
                  false

            | `BUTTON_RELEASE, _ | `TWO_BUTTON_PRESS, _ | _ ->
                false
            )

      | Column j ->
            (match GdkEvent.get_type ev, GdkEvent.Button.button ev with
            | `TWO_BUTTON_PRESS, 1 ->
                pr2 (spf "double clicking on column j");
                let node = w.m.DM.i_to_name.(j) in
                w.path <- add_path (DM.Expand node) w.path;
                recompute_matrix w;
                true
            | `BUTTON_PRESS, 3 ->
                pr2 (spf "right clicking on column j");
                let node = w.m.DM.i_to_name.(j) in
                w.path <- add_path (DM.Focus (node, DM.DepsIn)) w.path;
                recompute_matrix w;
                true

            | _ -> false
            )
      )
  )
