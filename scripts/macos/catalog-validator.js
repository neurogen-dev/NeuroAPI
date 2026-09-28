// JXA/Foundation is part of macOS; no Python or Node dependency at runtime.
ObjC.import('Foundation')

function requireValue(condition) {
  if (!condition) throw new Error('Invalid model catalog')
}
function object(value) { return value !== null && typeof value === 'object' && !Array.isArray(value) }
function keys(value, allowed) {
  requireValue(object(value))
  requireValue(Object.keys(value).every(function (key) { return allowed.indexOf(key) !== -1 }))
}
function text(value, limit) {
  return typeof value === 'string' && value.length <= limit && !/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/.test(value)
}
function modelID(value) { return typeof value === 'string' && /^[A-Za-z0-9][A-Za-z0-9._:/-]{0,255}$/.test(value) }
function integer(value, min, max) { return Number.isSafeInteger(value) && value >= min && value <= max }
function readBounded(handle, limit) {
  var data = $.NSMutableData.data
  while (true) {
    var chunk = handle.readDataOfLength(65536)
    if (Number(chunk.length) === 0) break
    requireValue(Number(data.length) + Number(chunk.length) <= limit)
    data.appendData(chunk)
  }
  var decoded = $.NSString.alloc.initWithDataEncoding(data, $.NSUTF8StringEncoding)
  requireValue(!decoded.isNil())
  return ObjC.unwrap(decoded)
}
function write(path, value) {
  requireValue($(value).dataUsingEncoding($.NSUTF8StringEncoding).writeToFileAtomically($(path), true))
}
function validateCodex(data) {
  keys(data, ['models', 'default_model'])
  requireValue(Array.isArray(data.models) && data.models.length > 0 && data.models.length <= 128)
  var seen = Object.create(null)
  var strings = ['display_name', 'description', 'base_instructions']
  var bools = ['supported_in_api', 'supports_reasoning_summary_parameter', 'support_verbosity', 'supports_parallel_tool_calls', 'supports_search_tool', 'use_responses_lite']
  var counts = ['priority', 'context_window', 'max_context_window', 'auto_compact_token_limit', 'effective_context_window_percent', 'input_token_limit', 'output_token_limit']
  var allowed = ['slug', 'supported_reasoning_levels', 'shell_type', 'visibility', 'model_messages', 'truncation_policy', 'experimental_supported_tools', 'input_modalities'].concat(strings, bools, counts)
  data.models.forEach(function (model) {
    keys(model, allowed)
    requireValue(modelID(model.slug) && !seen[model.slug])
    seen[model.slug] = model
    strings.forEach(function (key) { requireValue(text(model[key], 65536)) })
    bools.forEach(function (key) { requireValue(typeof model[key] === 'boolean') })
    counts.forEach(function (key) { requireValue(integer(model[key], 0, 1000000000)) })
    requireValue(model.context_window > 0 && model.max_context_window >= model.context_window)
    requireValue(model.effective_context_window_percent > 0 && model.effective_context_window_percent <= 100)
    requireValue(['shell_command', 'default', 'local', 'unified_exec', 'disabled'].indexOf(model.shell_type) !== -1)
    requireValue(['list', 'hide', 'hidden'].indexOf(model.visibility) !== -1)
    requireValue(Array.isArray(model.supported_reasoning_levels) && model.supported_reasoning_levels.length <= 16)
    model.supported_reasoning_levels.forEach(function (level) {
      keys(level, ['effort', 'description'])
      requireValue(['none', 'minimal', 'low', 'medium', 'high', 'xhigh', 'max', 'ultra'].indexOf(level.effort) !== -1 && text(level.description, 4096))
    })
    keys(model.model_messages, ['instructions_template'])
    requireValue(text(model.model_messages.instructions_template, 65536))
    keys(model.truncation_policy, ['mode', 'limit'])
    requireValue(['bytes', 'tokens'].indexOf(model.truncation_policy.mode) !== -1 && integer(model.truncation_policy.limit, 1, 1000000000))
    requireValue(Array.isArray(model.experimental_supported_tools) && model.experimental_supported_tools.length <= 64)
    model.experimental_supported_tools.forEach(function (tool) { requireValue(modelID(tool)) })
    requireValue(Array.isArray(model.input_modalities) && model.input_modalities.length > 0 && model.input_modalities.length <= 4)
    model.input_modalities.forEach(function (mode) { requireValue(['text', 'image', 'audio', 'video'].indexOf(mode) !== -1) })
  })
  requireValue(modelID(data.default_model) && seen[data.default_model])
  requireValue(seen[data.default_model].visibility === 'list' && seen[data.default_model].supported_in_api === true)
}
function validateClaude(data) {
  keys(data, ['model', 'availableModels', 'enforceAvailableModels', 'modelPicker', 'env', 'fallbackModel'])
  requireValue(Array.isArray(data.availableModels) && data.availableModels.length > 0 && data.availableModels.length <= 256)
  var seen = Object.create(null)
  data.availableModels.forEach(function (model) { requireValue(modelID(model) && !seen[model]); seen[model] = true })
  requireValue(modelID(data.model) && seen[data.model] && data.enforceAvailableModels === true)
  requireValue(Array.isArray(data.fallbackModel) && data.fallbackModel.length === 0)
  keys(data.modelPicker, ['options', 'replaceBuiltInOptions'])
  requireValue(data.modelPicker.replaceBuiltInOptions === true && Array.isArray(data.modelPicker.options) && data.modelPicker.options.length > 0 && data.modelPicker.options.length <= 128)
  var options = Object.create(null)
  data.modelPicker.options.forEach(function (option) {
    keys(option, ['model', 'label', 'description'])
    requireValue(modelID(option.model) && seen[option.model] && !options[option.model])
    options[option.model] = true
    if (option.label !== undefined) requireValue(text(option.label, 512))
    if (option.description !== undefined) requireValue(text(option.description, 4096))
  })
  requireValue(options[data.model] === true)
  keys(data.env, ['ANTHROPIC_DEFAULT_SONNET_MODEL', 'ANTHROPIC_DEFAULT_OPUS_MODEL', 'ANTHROPIC_DEFAULT_HAIKU_MODEL', 'ANTHROPIC_DEFAULT_FABLE_MODEL'])
  Object.keys(data.env).forEach(function (key) {
    requireValue(modelID(data.env[key]) && seen[data.env[key]])
    var family = key.slice('ANTHROPIC_DEFAULT_'.length, -'_MODEL'.length).toLowerCase()
    requireValue(new RegExp('^claude-' + family + '(?:[-.]|$)').test(data.env[key]))
  })
}
function run(args) {
  requireValue(args.length === 3 && ['codex', 'claude'].indexOf(args[0]) !== -1)
  var raw = readBounded($.NSFileHandle.fileHandleWithStandardInput, 4194310)
  var secretHandle = $.NSFileHandle.fileHandleForReadingAtPath('/dev/fd/3')
  requireValue(!secretHandle.isNil())
  var secret = readBounded(secretHandle, 4096)
  requireValue(secret.length > 0 && raw.indexOf(secret) === -1)
  requireValue(raw.slice(-4) === '\n200')
  var data = JSON.parse(raw.slice(0, -4))
  requireValue(JSON.stringify(data).indexOf(secret) === -1)
  if (args[0] === 'codex') {
    validateCodex(data)
    write(args[1] + '/models.json', JSON.stringify({models: data.models}))
    write(args[1] + '/model.txt', data.default_model + '\n')
  } else {
    validateClaude(data)
    // Claude reapplies lower-priority settings.env after inheriting the process
    // environment. Neutralize foreign auth/provider values in both layers.
    ;['ANTHROPIC_SMALL_FAST_MODEL', 'CLAUDE_CODE_SUBAGENT_MODEL', 'ANTHROPIC_DEFAULT_MODEL',
      'ANTHROPIC_AUTH_TOKEN', 'ANTHROPIC_API_KEY', 'CLAUDE_CODE_OAUTH_TOKEN',
      'ANTHROPIC_CUSTOM_HEADERS', 'CLAUDE_CODE_USE_BEDROCK', 'CLAUDE_CODE_USE_VERTEX',
      'CLAUDE_CODE_USE_FOUNDRY', 'CLAUDE_CODE_USE_ANTHROPIC_AWS', 'CLAUDE_CODE_USE_MANTLE'].forEach(function (key) {
      data.env[key] = ''
    })
    data.env.ANTHROPIC_BASE_URL = 'https://neuroapi.host/v1/claude-code'
    data.env.ANTHROPIC_MODEL = data.model
    // Keep first-request quota reservations bounded. Claude Code can continue
    // generation in another turn when a response reaches this limit.
    data.env.CLAUDE_CODE_MAX_OUTPUT_TOKENS = '4096'
    data.apiKeyHelper = "'" + args[2].replace(/'/g, "'\\''") + "'"
    write(args[1] + '/settings.json', JSON.stringify(data))
  }
}
