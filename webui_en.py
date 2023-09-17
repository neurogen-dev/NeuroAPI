import os
import logging
import sys

import gradio as gr
import asyncio

import aiohttp
from aiohttp import web
import aiofiles

from modules import config
from modules.config import *
from modules.utils import *
from modules.presets import *
from modules.overwrites import *
from modules.models.models import get_model
import fastwsgi
from backend.backend import app

import threading
import time
import json
import random
import time

from multiprocessing import Process

import logging
import uvicorn

logging.getLogger("httpx").setLevel(logging.WARNING)

gr.Chatbot._postprocess_chat_messages = postprocess_chat_messages
gr.Chatbot.postprocess = postprocess

with open("assets/custom.css", "r") as f:
    customCSS = f.read()

def create_new_model():
    return get_model(model_name=MODELS[DEFAULT_MODEL], access_key=my_api_key)[0]

with gr.Blocks(css=customCSS, theme=small_and_beautiful_theme) as demo:
    user_name = gr.State("")
    promptTemplates = gr.State(load_template(get_template_names(plain=True)[0], mode=2))
    user_question = gr.State("")
    assert type(my_api_key) == str
    user_api_key = gr.State(my_api_key)
    current_model = gr.State(create_new_model)

    topic = gr.State("Untitled conversation")

    with gr.Row():
        gr.HTML(CHUANHU_TITLE, elem_id="app_title")
        status_display = gr.Markdown(get_geoip(), elem_id="status_display")
    with gr.Row(elem_id="float_display"):
        user_info = gr.Markdown(value="getting user info...", elem_id="user_info")
        update_info = gr.HTML(get_html("update.html").format(
            current_version=repo_html(),
            version_time=version_time(),
            cancel_btn="Cancel",
            update_btn="Update",
            seenew_btn="Details",
            ok_btn="Ok",
        ), visible=check_update)

    with gr.Row(equal_height=True):
        with gr.Column(scale=5):
            with gr.Row():
                chatbot = gr.Chatbot(label="Chuanhu Chat", elem_id="chuanhu_chatbot", latex_delimiters=latex_delimiters_set, height=700)
            with gr.Row():
                with gr.Column(min_width=225, scale=12):
                    user_input = gr.Textbox(
                        elem_id="user_input_tb",
                        show_label=False, placeholder="Please type your request here.",
                        container=False
                    )
                with gr.Column(min_width=42, scale=1):
                    submitBtn = gr.Button(value="", variant="primary", elem_id="submit_btn")
                    cancelBtn = gr.Button(value="", variant="secondary", visible=False, elem_id="cancel_btn")
            with gr.Row():
                emptyBtn = gr.Button(
                    "🧹 New conversation", elem_id="empty_btn"
                )
                retryBtn = gr.Button("🔄 Regenerate")
                delFirstBtn = gr.Button("🗑️ Delete oldest conversation")
                delLastBtn = gr.Button("🗑️ Delete last conversation")
                with gr.Row(visible=False) as like_dislike_area:
                    with gr.Column(min_width=20, scale=1):
                        likeBtn = gr.Button("👍")
                    with gr.Column(min_width=20, scale=1):
                        dislikeBtn = gr.Button("👎")

        with gr.Column():
            with gr.Column(min_width=50, scale=1):
                with gr.Tab(label="Model"):
                    keyTxt = gr.Textbox(
                        show_label=True,
                        placeholder="Your API-key...",
                        value=hide_middle_chars(user_api_key.value),
                        type="password",
                        visible=not HIDE_MY_KEY,
                        label="ChimeraAPI key",
                    )
                    if multi_api_key:
                        usageTxt = gr.Markdown("Multiplayer mode is enabled, no need to enter a key, you can start a conversation right away", elem_id="usage_display", elem_classes="insert_block")
                    else:
                        usageTxt = gr.Markdown("**Send a message** или **Send the key** to display credit", elem_id="usage_display", elem_classes="insert_block")
                    model_select_dropdown = gr.Dropdown(
                        label="Select model", choices=MODELS, multiselect=False, value=MODELS[DEFAULT_MODEL], interactive=True
                    )
                    lora_select_dropdown = gr.Dropdown(
                        label="Select LoRA model", choices=[], multiselect=False, interactive=True, visible=False
                    )
                    with gr.Row():
                        single_turn_checkbox = gr.Checkbox(label="Single-turn conversation mode", value=False, elem_classes="switch_checkbox")
                        use_websearch_checkbox = gr.Checkbox(label="Use online search", value=False, elem_classes="switch_checkbox")

                    language_select_dropdown = gr.Dropdown(
                        label="Select response language (for search and indexing functions)",
                        choices=REPLY_LANGUAGES,
                        multiselect=False,
                        value=REPLY_LANGUAGES[0],
                    )
                    index_files = gr.Files(label="Load (ChimeraAPI)", type="file", visible=False)
                    two_column = gr.Checkbox(label="Two-column pdf", value=advance_docs["pdf"].get("two_column", False), visible=False)
                    summarize_btn = gr.Button("Summarize", visible=False)
                    # TODO: OCR formulas
                    # formula_ocr = gr.Checkbox(label="OCR formulas", value=advance_docs["pdf"].get("formula_ocr", False))

                with gr.Tab(label="Prompt"):
                    systemPromptTxt = gr.Textbox(
                        show_label=True,
                        placeholder="Type System Prompt here...",
                        label="System prompt",
                        value=INITIAL_SYSTEM_PROMPT,
                        lines=10
                    )
                    with gr.Accordion(label="Load Prompt Template", open=True):
                        with gr.Column():
                            with gr.Row():
                                with gr.Column(scale=6):
                                    templateFileSelectDropdown = gr.Dropdown(
                                        label="Select a file with a collection of prompt templates",
                                        choices=get_template_names(plain=True),
                                        multiselect=False,
                                        value=get_template_names(plain=True)[0],
                                        container=False,
                                    )
                                with gr.Column(scale=1):
                                    templateRefreshBtn = gr.Button("🔄 Refresh")
                            with gr.Row():
                                with gr.Column():
                                    templateSelectDropdown = gr.Dropdown(
                                        label="Load from prompt template",
                                        choices=load_template(
                                            get_template_names(plain=True)[0], mode=1
                                        ),
                                        multiselect=False,
                                        container=False,
                                    )

                with gr.Tab(label="Save/Load"):
                    with gr.Accordion(label="Save/Load conversation history", open=True):
                        with gr.Column():
                            with gr.Row():
                                with gr.Column(scale=6):
                                    historyFileSelectDropdown = gr.Dropdown(
                                        label="Load conversation from history",
                                        choices=get_history_names(plain=True),
                                        multiselect=False,
                                        container=False,
                                    )
                                with gr.Row():
                                    with gr.Column(min_width=42, scale=1):
                                        historyRefreshBtn = gr.Button("🔄 Refresh")
                                    with gr.Column(min_width=42, scale=1):
                                        historyDeleteBtn = gr.Button("🗑️ Delete")
                            with gr.Row():
                                with gr.Column(scale=6):
                                    saveFileName = gr.Textbox(
                                        show_label=True,
                                        placeholder="By default, the file name is set to .json, but you have the option to select .md",
                                        label="Select a file name to saving",
                                        value="History of conversation",
                                        container=False,
                                    )
                                with gr.Column(scale=1):
                                    saveHistoryBtn = gr.Button("💾 Save the conversation")
                                    exportMarkdownBtn = gr.Button("📝 Export to Markdown")
                                    gr.Markdown("By default saved in the history folder")
                            with gr.Row():
                                with gr.Column():
                                    downloadFile = gr.File(interactive=True)

                with gr.Tab(label="Advanced"):
                    gr.HTML(get_html("appearance_switcher.html").format(label="Switch light/dark theme"), elem_classes="insert_block")
                    use_streaming_checkbox = gr.Checkbox(
                            label="Text streaming", value=True, visible=ENABLE_STREAMING_OPTION, elem_classes="switch_checkbox"
                        )
                    checkUpdateBtn = gr.Button("🔄 Check for updates...", visible=check_update)
                    gr.Markdown("# ⚠️ CAUTION ⚠️", elem_id="advanced_warning")
                    with gr.Accordion("Parameters", open=False):
                        temperature_slider = gr.Slider(
                            minimum=-0,
                            maximum=2.0,
                            value=1.0,
                            step=0.1,
                            interactive=True,
                            label="temperature",
                        )
                        top_p_slider = gr.Slider(
                            minimum=-0,
                            maximum=1.0,
                            value=1.0,
                            step=0.05,
                            interactive=True,
                            label="top-p",
                        )
                        n_choices_slider = gr.Slider(
                            minimum=1,
                            maximum=10,
                            value=1,
                            step=1,
                            interactive=True,
                            label="n choices",
                        )
                        stop_sequence_txt = gr.Textbox(
                            show_label=True,
                            placeholder="Enter comma-separated stop words here...",
                            label="stop",
                            value="",
                            lines=1,
                        )
                        max_context_length_slider = gr.Slider(
                            minimum=1,
                            maximum=100000,
                            value=4000,
                            step=1,
                            interactive=True,
                            label="max context",
                        )
                        max_generation_slider = gr.Slider(
                            minimum=1,
                            maximum=100000,
                            value=2000,
                            step=1,
                            interactive=True,
                            label="max generations",
                        )
                        presence_penalty_slider = gr.Slider(
                            minimum=-2.0,
                            maximum=2.0,
                            value=0.0,
                            step=0.01,
                            interactive=True,
                            label="presence penalty",
                        )
                        frequency_penalty_slider = gr.Slider(
                            minimum=-2.0,
                            maximum=2.0,
                            value=0.0,
                            step=0.01,
                            interactive=True,
                            label="frequency penalty",
                        )
                        logit_bias_txt = gr.Textbox(
                            show_label=True,
                            placeholder="word:likelihood",
                            label="logit bias",
                            value="",
                            lines=1,
                        )
                        user_identifier_txt = gr.Textbox(
                            show_label=True,
                            placeholder="Used to localize abuses",
                            label="User Name",
                            value=user_name.value,
                            lines=1,
                        )

                    with gr.Accordion("Network settings", open=False):
                        # 优先展示自定义的api_host
                        apihostTxt = gr.Textbox(
                            show_label=True,
                            placeholder="Enter API-Host here...",
                            label="API-Host",
                            value=config.api_host or shared.API_HOST,
                            lines=1,
                            container=False,
                        )
                        changeAPIURLBtn = gr.Button("🔄 Change API address")
                        proxyTxt = gr.Textbox(
                            show_label=True,
                            placeholder="Enter address of proxy here...",
                            label="Proxy address (e.g: http://127.0.0.1:10809）",
                            value="",
                            lines=2,
                            container=False,
                        )
                        changeProxyBtn = gr.Button("🔄 Change proxy address")
                        default_btn = gr.Button("🔙 Restore default settings")

    gr.Markdown(CHUANHU_DESCRIPTION, elem_id="description")
    gr.HTML(get_html("footer.html").format(versions=versions_html()), elem_id="footer")

    # https://github.com/gradio-app/gradio/pull/3296
    def create_greeting(request: gr.Request):
        if hasattr(request, "username") and request.username: # is not None or is not ""
            logging.info(f"Get User Name: {request.username}")
            user_info, user_name = gr.Markdown.update(value=f"User: {request.username}"), request.username
        else:
            user_info, user_name = gr.Markdown.update(value=f"", visible=False), ""
        current_model = get_model(model_name=MODELS[DEFAULT_MODEL], access_key=my_api_key)[0]
        current_model.set_user_identifier(user_name)
        chatbot = gr.Chatbot.update(label=MODELS[DEFAULT_MODEL])
        return user_info, user_name, current_model, toggle_like_btn_visibility(DEFAULT_MODEL), *current_model.auto_load(), get_history_names(False, user_name), chatbot
    demo.load(create_greeting, inputs=None, outputs=[user_info, user_name, current_model, like_dislike_area, systemPromptTxt, chatbot, historyFileSelectDropdown, chatbot], api_name="load")
    chatgpt_predict_args = dict(
        fn=predict,
        inputs=[
            current_model,
            user_question,
            chatbot,
            use_streaming_checkbox,
            use_websearch_checkbox,
            index_files,
            language_select_dropdown,
        ],
        outputs=[chatbot, status_display],
        show_progress=True,
    )

    start_outputing_args = dict(
        fn=start_outputing,
        inputs=[],
        outputs=[submitBtn, cancelBtn],
        show_progress=True,
    )

    end_outputing_args = dict(
        fn=end_outputing, inputs=[], outputs=[submitBtn, cancelBtn]
    )

    reset_textbox_args = dict(
        fn=reset_textbox, inputs=[], outputs=[user_input]
    )

    transfer_input_args = dict(
        fn=transfer_input, inputs=[user_input], outputs=[user_question, user_input, submitBtn, cancelBtn], show_progress=True
    )

    get_usage_args = dict(
        fn=billing_info, inputs=[current_model], outputs=[usageTxt], show_progress=False
    )

    load_history_from_file_args = dict(
        fn=load_chat_history,
        inputs=[current_model, historyFileSelectDropdown, user_name],
        outputs=[saveFileName, systemPromptTxt, chatbot]
    )

    refresh_history_args = dict(
        fn=get_history_names, inputs=[gr.State(False), user_name], outputs=[historyFileSelectDropdown]
    )


    # Chatbot
    cancelBtn.click(interrupt, [current_model], [])

    user_input.submit(**transfer_input_args).then(**chatgpt_predict_args).then(**end_outputing_args)
    user_input.submit(**get_usage_args)

    submitBtn.click(**transfer_input_args).then(**chatgpt_predict_args, api_name="predict").then(**end_outputing_args)
    submitBtn.click(**get_usage_args)

    index_files.change(handle_file_upload, [current_model, index_files, chatbot, language_select_dropdown], [index_files, chatbot, status_display])
    summarize_btn.click(handle_summarize_index, [current_model, index_files, chatbot, language_select_dropdown], [chatbot, status_display])

    emptyBtn.click(
        reset,
        inputs=[current_model],
        outputs=[chatbot, status_display],
        show_progress=True,
        _js='()=>{clearHistoryHtml();}',
    )

    retryBtn.click(**start_outputing_args).then(
        retry,
        [
            current_model,
            chatbot,
            use_streaming_checkbox,
            use_websearch_checkbox,
            index_files,
            language_select_dropdown,
        ],
        [chatbot, status_display],
        show_progress=True,
    ).then(**end_outputing_args)
    retryBtn.click(**get_usage_args)

    delFirstBtn.click(
        delete_first_conversation,
        [current_model],
        [status_display],
    )

    delLastBtn.click(
        delete_last_conversation,
        [current_model, chatbot],
        [chatbot, status_display],
        show_progress=False
    )

    likeBtn.click(
        like,
        [current_model],
        [status_display],
        show_progress=False
    )

    dislikeBtn.click(
        dislike,
        [current_model],
        [status_display],
        show_progress=False
    )

    two_column.change(update_doc_config, [two_column], None)

    # LLM Models
    keyTxt.change(set_key, [current_model, keyTxt], [user_api_key, status_display], api_name="set_key").then(**get_usage_args)
    keyTxt.submit(**get_usage_args)
    single_turn_checkbox.change(set_single_turn, [current_model, single_turn_checkbox], None)
    model_select_dropdown.change(get_model, [model_select_dropdown, lora_select_dropdown, user_api_key, temperature_slider, top_p_slider, systemPromptTxt, user_name], [current_model, status_display, chatbot, lora_select_dropdown], show_progress=True, api_name="get_model")
    model_select_dropdown.change(toggle_like_btn_visibility, [model_select_dropdown], [like_dislike_area], show_progress=False)
    lora_select_dropdown.change(get_model, [model_select_dropdown, lora_select_dropdown, user_api_key, temperature_slider, top_p_slider, systemPromptTxt, user_name], [current_model, status_display, chatbot], show_progress=True)

    # Template
    systemPromptTxt.change(set_system_prompt, [current_model, systemPromptTxt], None)
    templateRefreshBtn.click(get_template_names, None, [templateFileSelectDropdown])
    templateFileSelectDropdown.change(
        load_template,
        [templateFileSelectDropdown],
        [promptTemplates, templateSelectDropdown],
        show_progress=True,
    )
    templateSelectDropdown.change(
        get_template_content,
        [promptTemplates, templateSelectDropdown, systemPromptTxt],
        [systemPromptTxt],
        show_progress=True,
    )

    # S&L
    saveHistoryBtn.click(
        save_chat_history,
        [current_model, saveFileName, chatbot, user_name],
        downloadFile,
        show_progress=True,
    )
    saveHistoryBtn.click(get_history_names, [gr.State(False), user_name], [historyFileSelectDropdown])
    exportMarkdownBtn.click(
        export_markdown,
        [current_model, saveFileName, chatbot, user_name],
        downloadFile,
        show_progress=True,
    )
    historyRefreshBtn.click(**refresh_history_args)
    historyDeleteBtn.click(delete_chat_history, [current_model, historyFileSelectDropdown, user_name], [status_display, historyFileSelectDropdown, chatbot], _js='(a,b,c)=>{return showConfirmationDialog(a, b, c);}')
    historyFileSelectDropdown.change(**load_history_from_file_args)
    downloadFile.change(upload_chat_history, [current_model, downloadFile, user_name], [saveFileName, systemPromptTxt, chatbot])

    # Advanced
    max_context_length_slider.change(set_token_upper_limit, [current_model, max_context_length_slider], None)
    temperature_slider.change(set_temperature, [current_model, temperature_slider], None)
    top_p_slider.change(set_top_p, [current_model, top_p_slider], None)
    n_choices_slider.change(set_n_choices, [current_model, n_choices_slider], None)
    stop_sequence_txt.change(set_stop_sequence, [current_model, stop_sequence_txt], None)
    max_generation_slider.change(set_max_tokens, [current_model, max_generation_slider], None)
    presence_penalty_slider.change(set_presence_penalty, [current_model, presence_penalty_slider], None)
    frequency_penalty_slider.change(set_frequency_penalty, [current_model, frequency_penalty_slider], None)
    logit_bias_txt.change(set_logit_bias, [current_model, logit_bias_txt], None)
    user_identifier_txt.change(set_user_identifier, [current_model, user_identifier_txt], None)

    default_btn.click(
        reset_default, [], [apihostTxt, proxyTxt, status_display], show_progress=True
    )
    changeAPIURLBtn.click(
        change_api_host,
        [apihostTxt],
        [status_display],
        show_progress=True,
    )
    changeProxyBtn.click(
        change_proxy,
        [proxyTxt],
        [status_display],
        show_progress=True,
    )
    checkUpdateBtn.click(fn=None, _js='()=>{manualCheckUpdate();}')

logging.info(
    colorama.Back.BLUE
    + "Version" + VERSION
    + colorama.Style.RESET_ALL
)

logging.info(
    colorama.Back.GREEN
    + "\n WebUI address: http://127.0.0.1:7860 "
    + colorama.Style.RESET_ALL
)

demo.title = "NeuroGPT 🚀"

def run_gradio_server():
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop) 
   
    reload_javascript()
    demo.queue(concurrency_count=CONCURRENT_COUNT).launch(
      blocked_paths=["config.json"],
      server_name=server_name,
      server_port=server_port,
      share=share,
      auth=auth_list if authflag else None,
      favicon_path="./assets/favicon.ico",
      inbrowser=not dockerflag,
    )

def run_api_server():
    fastwsgi.run(wsgi_app=app, host='0.0.0.0', port=1337)

if __name__ == "__main__":
    api_process = Process(target=run_api_server) 
    api_process.start()

    run_gradio_server()