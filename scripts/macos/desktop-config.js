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
function disableRemotePlugins(source, newline) {
  var firstTable = /^[ \t]*\[[^\r\n]*\]/m.exec(source)
  var root = source.slice(0, firstTable ? firstTable.index : source.length)
  if (/^[ \t]*(?:features|"features"|'features')[ \t]*(?:=|\.)/m.test(root))
    fail('Inline or dotted features require manual Codex Desktop setup')
  var headers = [], match
  var headerPattern = /^[ \t]*\[[ \t]*(?:features|"features"|'features')[ \t]*\][ \t]*(?:#.*)?\r?$/gm
  while ((match = headerPattern.exec(source)) !== null) headers.push(match)
  if (headers.length > 1) fail('Duplicate Codex features table')
  if (headers.length === 0) {
    if (source.length && !/\n$/.test(source)) source += newline
    return source + newline + '[features]' + newline + 'remote_plugin = false' + newline
  }
  var start = headers[0].index + headers[0][0].length
  var following = /^[ \t]*\[[^\r\n]*\]/m.exec(source.slice(start))
  var end = following ? start + following.index : source.length
  var section = source.slice(start, end)
  var toggles = [], toggle
  var togglePattern = /^([ \t]*)(?:remote_plugin|"remote_plugin"|'remote_plugin')[ \t]*=[ \t]*(.*)$/gm
  while ((toggle = togglePattern.exec(section)) !== null) toggles.push(toggle)
  if (toggles.length > 1) fail('Duplicate Codex remote_plugin setting')
  if (toggles.length === 1) {
    var suffix = /^(?:true|false)([ \t]*(?:#.*)?\r?)$/.exec(toggles[0][2])
    if (!suffix) fail('Unsupported Codex remote_plugin setting')
    section = section.slice(0, toggles[0].index) + toggles[0][1] + 'remote_plugin = false' + suffix[1] +
      section.slice(toggles[0].index + toggles[0][0].length)
  } else {
    section = newline + 'remote_plugin = false' + section
    if (!/\n$/.test(section)) section += newline
  }
  return source.slice(0, start) + section + source.slice(end)
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
  result = rootSetting(result, 'web_search', 'live', newline)
  result = disableRemotePlugins(result, newline)
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
