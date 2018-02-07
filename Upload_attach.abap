*&---------------------------------------------------------------------*
*& Report  ZMJ_imp_file
*&
*&---------------------------------------------------------------------*
"  Hoje irei mostrar um 'Method' que faz a mesma coisa que o Gui_upload

REPORT ZMJ_IMP_FILE.


 types: BEGIN OF hex_record,

    myhex TYPE x,

END OF hex_record.


  DATA: tab TYPE TABLE OF soli.


  " Variáveis.
  data : v_file       TYPE string,              "Diretório + Nome arquivo
         v_perc(05)   TYPE p DECIMALS 2,        "Percentual do Processo
         c_x          type c VALUE 'X',         " COnstante X
         v_title      TYPE string,              "Título da Janela
         c_idiret     TYPE string VALUE 'C:\'   "Diretório Inicial
        .

DATA:
li_content   TYPE  STANDARD TABLE OF  soli,
li_objhead   TYPE STANDARD TABLE OF  soli,
lwa_folmem_k TYPE sofmk,
lwa_note     TYPE borident,
lwa_object   TYPE borident,
lwa_obj_id   TYPE soodk,
lwa_content  TYPE soli,
lwa_fol_id   TYPE soodk,
lwa_obj_data TYPE sood1,
lv_ep_note   TYPE borident-objkey,
lv_lifnr     TYPE c LENGTH 20,
lv_file      TYPE string,
lv_filename  TYPE c LENGTH 100, " file name and ext
lv_extension TYPE c LENGTH 4. " extension only
*   Refresh data
REFRESH: li_content[], li_objhead[].



SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE text-p01.
PARAMETERS:
  p_pathho  TYPE file_table-filename.    "Dados Cabeçalho

SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE text-001.
PARAMETERS:
p_objid  TYPE swo_typeid,               " Any object like material no/vendor
"/customer/po/pr etc
p_bo     TYPE swo_objtyp.                " Business object like LFA1 for vendor
SELECTION-SCREEN END OF BLOCK b2.


*----------------------------------------------------------------------*
* At Selection-Screen                                                  *
*----------------------------------------------------------------------*
* Ajuda na Escolha do Diretório para gravação do Arquivo
AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_pathho.
  PERFORM f_busca_caminho CHANGING p_pathho.

INITIALIZATION.

START-OF-SELECTION.

*   Abre o arquivo TXT e joga na tabela interna, desconsiderando
*   cabeçalho
*   text-001 - Dados Cabeçalho
*   text-002 - Dados Item
    PERFORM f_carrega_arquivo:
" espero que vcs tenha percebido que mesmo as tabelas tendo campos e
" qtde de campos diferentes ele faz mesmo assim, o importante é vc
" declarar a tabela certinha.
     TABLES tab USING p_pathho text-001.
"  Durante o processo de debugar, olhe como estão as tabelas internas,
" adicione mais campos para as tabelas internas e respectivamente dentro
" do arquivo txt caso queira.

li_content[] = tab[].

* Get folder id
CALL FUNCTION 'SO_FOLDER_ROOT_ID_GET'
EXPORTING
region                = 'B'
IMPORTING
folder_id             = lwa_fol_id
EXCEPTIONS
communication_failure = 1
owner_not_exist       = 2
system_failure        = 3
x_error               = 4
OTHERS                = 5.
* Sy-subrc check not required
* Keeping file in string data type
lv_file = p_pathho.
* You may not need this step. But  no harm in adding this
* Get file name and extension
CALL FUNCTION 'CH_SPLIT_FILENAME'
EXPORTING
complete_filename = lv_file
IMPORTING
extension         = lv_extension
name_with_ext     = lv_filename
EXCEPTIONS
invalid_drive     = 1
invalid_path      = 2
OTHERS            = 3.
IF sy-subrc EQ 0.
* Object header
CLEAR lwa_content.
CONCATENATE '&SO_FILENAME=' lv_filename INTO lwa_content.
APPEND lwa_content TO li_objhead.
CLEAR lwa_content.
ENDIF.

lwa_object-objkey  = p_objid.
* For example, business object name for PO is BUS2012,
* business object for PR is BUS2105,
* business object for Vendor is LFA1 etc
lwa_object-objtype = p_bo.
*        lwa_object-logsys  = lv_logical_system.

lwa_obj_data-objsns = 'O'.
lwa_obj_data-objla = sy-langu.
lwa_obj_data-objdes = 'Attachment from server'.  .
lwa_obj_data-file_ext = lv_extension.

TRANSLATE lwa_obj_data-file_ext TO UPPER CASE.
* This is very important step. If your object size does not match with the input
* file size, then your object might get attached, but it will show error while you
* try to open it.
* If you have a way, where you can read the input file size directly, then assign
* it directly else, use the below formula
lwa_obj_data-objlen =  lines( li_content ) * 255.

* Insert data
CALL FUNCTION 'SO_OBJECT_INSERT'
EXPORTING
folder_id                  = lwa_fol_id
object_type                = 'EXT'
object_hd_change           = lwa_obj_data
IMPORTING
object_id                  = lwa_obj_id
TABLES
objhead                    = li_objhead
objcont                    = li_content
EXCEPTIONS
active_user_not_exist      = 1
communication_failure      = 2
component_not_available    = 3
dl_name_exist              = 4
folder_not_exist           = 5
folder_no_authorization    = 6
object_type_not_exist      = 7
operation_no_authorization = 8
owner_not_exist            = 9
parameter_error            = 10
substitute_not_active      = 11
substitute_not_defined     = 12
system_failure             = 13
x_error                    = 14
OTHERS                     = 15.
IF sy-subrc = 0 AND lwa_object-objkey IS NOT INITIAL.
lwa_folmem_k-foltp = lwa_fol_id-objtp.
lwa_folmem_k-folyr = lwa_fol_id-objyr.
lwa_folmem_k-folno = lwa_fol_id-objno.

* Please note: lwa_fol_id and lwa_obj_id are different work areas

lwa_folmem_k-doctp = lwa_obj_id-objtp.
lwa_folmem_k-docyr = lwa_obj_id-objyr.
lwa_folmem_k-docno = lwa_obj_id-objno.

lv_ep_note = lwa_folmem_k.
lwa_note-objtype = 'MESSAGE'.
*          lwa_note-logsys    = lv_logical_system.
lwa_note-objkey = lv_ep_note.

* Link it
CALL FUNCTION 'BINARY_RELATION_CREATE_COMMIT'
EXPORTING
obj_rolea      = lwa_object
obj_roleb      = lwa_note
relationtype   = 'ATTA'
EXCEPTIONS
no_model       = 1
internal_error = 2
unknown        = 3
OTHERS         = 4.
IF sy-subrc EQ 0.
* Commit it
COMMIT WORK.
WRITE:/ 'Attached successfully'.
ENDIF.
ELSE.
MESSAGE 'Error while opening file' TYPE 'I'.
LEAVE LIST-PROCESSING.
ENDIF.



*&---------------------------------------------------------------------*
*&      Form  F_CARREGA_ARQUIVO
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->p_table      Tabela interna do arquivo
*      -->p_pathfile   Diretório + Nome arquivo (tela de seleção)
*      -->p_text       Texto de Mensagem para identificar o arquivo
*----------------------------------------------------------------------*
form F_CARREGA_ARQUIVO  tables   p_table
                        using    p_pathfile
                                 p_text.
"  Move o valor da variável que contem o nome do arquivo, para dentro de
" uma outra variável para ter compatibilidade com o campo do method, senão
" não rola.
MOVE p_pathfile TO v_file.

* Exibe mensagem na barra de Status
* Msg: Carregando arquivo...
  ADD 5 TO v_perc.
  PERFORM f_progress_indicator USING 'Texto 1' v_perc.


* Abre arquivo de extensão '.TXT' que tem os campos separados por TAB e
* move dados para a tabela interna
  CALL METHOD cl_gui_frontend_services=>gui_upload
    EXPORTING
      filename                = v_file
      filetype                = 'BIN'
    CHANGING
      data_tab                = p_table[]
    EXCEPTIONS
      file_open_error         = 1
      file_read_error         = 2
      no_batch                = 3
      gui_refuse_filetransfer = 4
      invalid_type            = 5
      no_authority            = 6
      unknown_error           = 7
      bad_data_format         = 8
      header_not_allowed      = 9
      separator_not_allowed   = 10
      header_too_long         = 11
      unknown_dp_error        = 12
      access_denied           = 13
      dp_out_of_memory        = 14
      disk_full               = 15
      dp_timeout              = 16
      not_supported_by_gui    = 17
      error_no_gui            = 18
      OTHERS                  = 19.

  IF NOT sy-subrc IS INITIAL.

*   Msg: Erro na abertura do arquivo de XXX indicado.
    MESSAGE i836(sd) WITH text-010 p_text text-018.
    LEAVE LIST-PROCESSING.
  ENDIF.

  CLEAR v_file.

ENDFORM.                    " f_carrega_arquivo


*&---------------------------------------------------------------------*
*&      Form  f_progress_indicator
*&---------------------------------------------------------------------*
*       Indicador de visualização do progresso na janela atual
*----------------------------------------------------------------------*
*      -->P_TEXTO       Texto do processamento
*      -->P_PERCENT     Porcentual do processamento
*----------------------------------------------------------------------*
FORM f_progress_indicator  USING    p_texto   TYPE c
                                    p_percent TYPE p.

  CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
    EXPORTING
      percentage = p_percent
      text       = p_texto.

ENDFORM.                    " f_progress_indicator
*&---------------------------------------------------------------------*
*&      Form  F_BUSCA_CAMINHO
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      <--P_P_PATHHD  text
*----------------------------------------------------------------------*
form F_BUSCA_CAMINHO  changing p_file  TYPE file_table-filename.

    DATA:
    it_path  TYPE TABLE OF file_table,  "Diretório do arq escolhido
    st_path  TYPE file_table,           "Diretório do arq escolhido
    vl_rc    TYPE i,                    "N° de arq ou -1 se erro ocorre
    vl_user  TYPE i.                    "Ação do usuário

* Monta título da Janela:
* Msg: Selecione o arquivo desejado e Clique no botão [Abrir]
  CLEAR v_title.
  MOVE text-003 TO v_title.

* Chamada da caixa de diálogo para busca do arquivo
  CALL METHOD cl_gui_frontend_services=>file_open_dialog
    EXPORTING
      window_title            = v_title
      initial_directory       = c_idiret
      file_filter             = cl_gui_frontend_services=>filetype_text
    CHANGING
      file_table              = it_path
      rc                      = vl_rc
      user_action             = vl_user
    EXCEPTIONS
      file_open_dialog_failed = 1
      cntl_error              = 2
      error_no_gui            = 3
      not_supported_by_gui    = 4.

* Se não executou abertura com sucesso ou não selecionou nenhum arquivo
  IF NOT sy-subrc IS INITIAL OR it_path[] IS INITIAL.

*   Se usuário não cancelou a abertura ou não fechou a janela
*   Atributo ACTION_CANCEL = 9
    IF vl_user NE cl_gui_frontend_services=>action_cancel.

*     Msg: Arquivo inválido.
      MESSAGE i836(sd) WITH text-004.
    ELSE.
      EXIT.
    ENDIF.
  ELSE.

*   Retornando o diretório ao campo da tela de seleção
    CLEAR st_path.
    READ TABLE it_path INTO st_path INDEX vl_rc.
    IF sy-subrc EQ 0.
      MOVE st_path-filename TO p_file.
    ENDIF.
  ENDIF.

endform.                    " F_BUSCA_CAMINHO