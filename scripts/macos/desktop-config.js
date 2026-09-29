// macOS JXA: edit only the user-level Codex root settings owned by setup.
ObjC.import('Foundation')

function fail(message) { throw new Error(message) }
function read(path) {
  var handle = $.NSFileHandle.fileHandleForReadingAtPath($(path))
  if (handle.isNil()) fail('Cannot read Codex config')
  var data = handle.readDataToEndOfFile
  handle.closeFile
  if (Number(data.length) > 4194304) fail('Codex config is too large')
  var decoded = $.NSString.alloc.initWithDataEncoding(data, $.NSUTF8StringEncoding)
  if (decoded.isNil()) fail('Codex config is not UTF-8')
  return ObjC.unwrap(decoded)
}
function quote(value) {
  return '"' + value.replace(/\\/g, '\\\\').replace(/"/g, '\\"') + '"'
}
function rootSetting(source, key, value, newline) {
  // Match only a real table header at the beginning of a line.
  var table = /^[ \t]*\[[^\r\n]*\]/m.exec(source)
  var boundary = table ? table.index : source.length
  var root = source.slice(0, boundary)
  var rest = source.slice(boundary)
  var pattern = new RegExp('^([ \\t]*)' + key + '[ \\t]*=[ \\t]*(.*)$', 'gm')
  var matches = [], match
  while ((match = pattern.exec(root)) !== null) matches.push(match)
  if (matches.length > 1) fail('Duplicate Codex root setting: ' + key)
  if (matches.length === 1) {
    if (!/^"(?:[^"\\]|\\.)*"(?:[ \t]*#.*)?\r?$/.test(matches[0][2]))
      fail('Unsupported Codex root setting: ' + key)
    root = root.slice(0, matches[0].index) + matches[0][1] + key + ' = ' + quote(value) +
      root.slice(matches[0].index + matches[0][0].length)
  } else {
    root = key + ' = ' + quote(value) + newline + root
  }
  return root + rest
}
function run(args) {
  if (args.length !== 5) fail('Invalid desktop config arguments')
  var original = read(args[0])
  var model = read(args[1]).trim()
  if (!/^[A-Za-z0-9][A-Za-z0-9._:/-]{0,255}$/.test(model)) fail('Invalid default model')
  if (original.indexOf('"""') !== -1 || original.indexOf("'''") !== -1)
    fail('Multiline TOML requires manual Codex Desktop setup')
  if (/^[ \t]*\[[ \t]*model_providers\.(?:"neuroapi_agents"|'neuroapi_agents'|neuroapi_agents)(?:\.|[ \t]*\])/m.test(original))
    fail('Codex provider ID is already in use')
  if (original.indexOf('\u0000') !== -1) fail('Codex config contains NUL')
  var newline = original.indexOf('\r\n') !== -1 ? '\r\n' : '\n'
  var result = original
  result = rootSetting(result, 'model_provider', 'neuroapi_agents', newline)
  result = rootSetting(result, 'model_catalog_json', args[2], newline)
  result = rootSetting(result, 'model', model, newline)
  if (result.length && !/\n$/.test(result)) result += newline
  result += ('\n# NeuroAPI Agents desktop provider. Owned by the installer.\n' +
    '[model_providers.neuroapi_agents]\n' +
    'name = "NeuroAPI"\n' +
    'base_url = "https://codex.neuroapi.host/v1"\n' +
    'wire_api = "responses"\n' +
    'supports_websockets = false\n\n' +
    '[model_providers.neuroapi_agents.auth]\n' +
    'command = ' + quote(args[3]) + '\n' +
    'timeout_ms = 5000\n' +
    'refresh_interval_ms = 300000\n').replace(/\n/g, newline)
  if (!$(result).dataUsingEncoding($.NSUTF8StringEncoding).writeToFileAtomically($(args[4]), true))
    fail('Cannot stage Codex config')
}
