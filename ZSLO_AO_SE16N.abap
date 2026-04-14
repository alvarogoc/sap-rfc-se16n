*&---------------------------------------------------------------------*
*& Report ZSLO_AO_SE16N
*&---------------------------------------------------------------------*
*& Author : Alvaro Otero
*& Mail   : alvaro.otero@sap.com
*& Date   : 2026-04-13
*&---------------------------------------------------------------------*
*& Reads the same table from N RFC destinations and shows the merged
*& result in one ALV. The first column identifies the source RFC.
*& Selection screen is styled to mimic t-code SE16N.
*&---------------------------------------------------------------------*
*& SE16N element                               | In this report
*& ---------------------------------------------+-------------------------------------------------------------------
*& Table                                        | P_TABLE
*& Maximum no. of hits                          | P_MAX   (default 500) - caps rows across all RFCs
*& "Selection Criteria" frame                   | BLOCK b3 WITH FRAME TITLE - holds P_SELECT (field list) and P_WHERE
*& New: RFC multi-input                         | BLOCK b2 with SELECT-OPTIONS s_rfc ... NO INTERVALS
*&---------------------------------------------------------------------*
REPORT zslo_ao_se16n.

*----------------------------------------------------------------------*
* Global data                                                          *
*----------------------------------------------------------------------*
DATA:
  lv_tabletype       TYPE string,
  lv_where           TYPE string,
  lv_from            TYPE string,
  lv_select          TYPE string,
  lv_rfc             TYPE rfcdest,
  lo_datadescr       TYPE REF TO cl_abap_datadescr,
  lo_structdescr     TYPE REF TO cl_abap_structdescr,
  lo_aug_structdescr TYPE REF TO cl_abap_structdescr,
  lt_components      TYPE cl_abap_structdescr=>component_table,
  lt_aug_components  TYPE cl_abap_structdescr=>component_table,
  ls_aug_component   TYPE abap_componentdescr,
  ls_component       LIKE LINE OF lt_components,
  lo_dref_struc      TYPE REF TO data,
  lo_dref_table      TYPE REF TO data,
  lo_dref_aug_struc  TYPE REF TO data,
  lo_dref_aug_table  TYPE REF TO data,
  lo_alv             TYPE REF TO cl_salv_table,
  lex_message        TYPE REF TO cx_salv_msg,
  lo_layout_settings TYPE REF TO cl_salv_layout,
  lo_layout_key      TYPE        salv_s_layout_key,
  lo_columns         TYPE REF TO cl_salv_columns_table,
  lo_column          TYPE REF TO cl_salv_column,
  lex_not_found      TYPE REF TO cx_salv_not_found,
  lo_functions       TYPE REF TO cl_salv_functions_list.

FIELD-SYMBOLS:
  <struc>     TYPE any,
  <table>     TYPE ANY TABLE,
  <aug_struc> TYPE any,
  <aug_table> TYPE STANDARD TABLE,
  <src_line>  TYPE any,
  <src_field> TYPE any,
  <dst_field> TYPE any,
  <rfc_field> TYPE any.

*----------------------------------------------------------------------*
* Selection screen — SE16N look & feel                                 *
*----------------------------------------------------------------------*

* ---- Header panel (Table / Max hits) --------------------------------
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME.

PARAMETERS:     p_table  TYPE tabname    OBLIGATORY,
                p_max    TYPE i            DEFAULT 500   .

SELECTION-SCREEN END   OF BLOCK b1.

* ---- RFC destinations (multi-input, no intervals) -------------------
SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE tx_b2.
SELECT-OPTIONS   s_rfc   FOR lv_rfc NO INTERVALS.
SELECTION-SCREEN END   OF BLOCK b2.

* ---- Selection criteria --------------------------------------------
SELECTION-SCREEN BEGIN OF BLOCK b3 WITH FRAME TITLE tx_b3.
PARAMETERS:      p_select LIKE lv_select,
                 p_where  LIKE lv_where  OBLIGATORY.
SELECTION-SCREEN END   OF BLOCK b3.

*----------------------------------------------------------------------*
INITIALIZATION.
  tx_b2 = 'RFC Destinations'.
  tx_b3 = 'Selection Criteria'.
  " Field labels (also definable in text-symbols SE38 → Goto → Text elements)
  %_p_table_%_app_%-text  = 'Table'.
  %_p_max_%_app_%-text    = 'Maximum no. of hits'.
  %_p_select_%_app_%-text = 'Field list (SELECT)'.
  %_p_where_%_app_%-text  = 'WHERE clause'.
  %_s_rfc_%_app_%-text    = 'RFC dest.'.

*----------------------------------------------------------------------*
START-OF-SELECTION.

  IF s_rfc IS INITIAL.
    MESSAGE 'Please supply at least one RFC destination' TYPE 'E'.
  ENDIF.

* ---- 1) Resolve structure from the first RFC and build aug. table ---
  lv_tabletype = p_table.

  lo_datadescr ?= /slo/rrt_cl_read_table_access=>get_remote_data_type(
                      iv_destination = s_rfc[ 1 ]-low
                      iv_data_type   = lv_tabletype ).

  CREATE DATA lo_dref_struc TYPE HANDLE lo_datadescr.
  ASSIGN lo_dref_struc->* TO <struc>.
  CREATE DATA lo_dref_table LIKE STANDARD TABLE OF <struc>.
  ASSIGN lo_dref_table->* TO <table>.

  lo_structdescr ?= lo_datadescr.
  lt_components  = lo_structdescr->get_components( ).

  ls_aug_component-name = 'RFCDEST'.
  ls_aug_component-type ?= cl_abap_elemdescr=>get_c( 32 ).
  APPEND ls_aug_component TO lt_aug_components.
  APPEND LINES OF lt_components TO lt_aug_components.

  lo_aug_structdescr = cl_abap_structdescr=>create( lt_aug_components ).
  CREATE DATA lo_dref_aug_struc TYPE HANDLE lo_aug_structdescr.
  ASSIGN lo_dref_aug_struc->* TO <aug_struc>.
  CREATE DATA lo_dref_aug_table LIKE STANDARD TABLE OF <aug_struc>.
  ASSIGN lo_dref_aug_table->* TO <aug_table>.

* ---- 2) Loop RFC list, read and merge --------------------------------
  lv_where  = p_where.
  lv_from   = p_table.
  lv_select = p_select.

  LOOP AT s_rfc INTO DATA(ls_rfc) WHERE sign = 'I' AND option = 'EQ'.

    CLEAR <table>.

    TRY.
        CALL METHOD /slo/rrt_cl_read_table_access=>read_table
          EXPORTING
            iv_destination = ls_rfc-low
            iv_select      = lv_select
            iv_from        = lv_from
            iv_where       = lv_where
          IMPORTING
            et_table_data  = <table>.
      CATCH cx_root INTO DATA(lx_root).
        MESSAGE |RFC { ls_rfc-low }: { lx_root->get_text( ) }| TYPE 'I'.
        CONTINUE.
    ENDTRY.

    LOOP AT <table> ASSIGNING <src_line>.

      IF p_max > 0 AND lines( <aug_table> ) >= p_max.
        EXIT.
      ENDIF.

      CLEAR <aug_struc>.

      ASSIGN COMPONENT 'RFCDEST' OF STRUCTURE <aug_struc> TO <rfc_field>.
      <rfc_field> = ls_rfc-low.

      LOOP AT lt_components INTO ls_component.
        ASSIGN COMPONENT ls_component-name OF STRUCTURE <src_line>  TO <src_field>.
        ASSIGN COMPONENT ls_component-name OF STRUCTURE <aug_struc> TO <dst_field>.
        IF <src_field> IS ASSIGNED AND <dst_field> IS ASSIGNED.
          <dst_field> = <src_field>.
        ENDIF.
        UNASSIGN: <src_field>, <dst_field>.
      ENDLOOP.

      APPEND <aug_struc> TO <aug_table>.
    ENDLOOP.

  ENDLOOP.

* ---- 3) Display merged ALV ------------------------------------------
  TRY.
      cl_salv_table=>factory(
        IMPORTING
          r_salv_table = lo_alv
        CHANGING
          t_table      = <aug_table> ).
    CATCH cx_salv_msg INTO lex_message.
      MESSAGE lex_message TYPE 'E'.
  ENDTRY.

  lo_layout_settings   = lo_alv->get_layout( ).
  lo_layout_key-report = sy-repid.
  lo_layout_settings->set_key( lo_layout_key ).
  lo_layout_settings->set_save_restriction( if_salv_c_layout=>restrict_none ).

  lo_functions = lo_alv->get_functions( ).
  lo_functions->set_all( ).

  lo_columns = lo_alv->get_columns( ).
  lo_columns->set_optimize( ).

  TRY.
      lo_column = lo_columns->get_column( 'RFCDEST' ).
      lo_column->set_long_text(   'RFC Destination' ).
      lo_column->set_medium_text( 'RFC Dest.'       ).
      lo_column->set_short_text(  'RFC'             ).
      lo_columns->set_column_position( columnname = 'RFCDEST' position = 1 ).
    CATCH cx_salv_not_found INTO lex_not_found.
  ENDTRY.

  LOOP AT lt_components INTO ls_component.
    TRY.
        lo_column = lo_columns->get_column( CONV #( ls_component-name ) ).
        lo_column->set_long_text(   CONV #( ls_component-name ) ).
        lo_column->set_medium_text( CONV #( ls_component-name ) ).
        lo_column->set_short_text(  CONV #( ls_component-name ) ).
      CATCH cx_salv_not_found INTO lex_not_found.
    ENDTRY.
  ENDLOOP.

  lo_alv->display( ).
