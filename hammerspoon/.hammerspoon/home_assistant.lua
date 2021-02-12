require 'hs.json'

-- Runs a command in Home Assistant, returning its output (if any)
-- Example usage:
-- homeAssistantRun('POST', 'events/ios.action_fired', { ['actionName'] = 'Office Toggle' })
function homeAssistantRun(method, endpoint, parameters) 
    parameters = parameters or { }
    parametersJSONString = hs.json.encode(parameters)

    local commandString = '/Users/phajas/bin/home_assistant_run.bash'
    -- Add arguments to shell script
    commandString = commandString .. ' \'' 
    commandString = commandString .. method 
    commandString = commandString .. '\''

    commandString = commandString .. ' \'' 
    commandString = commandString .. endpoint 
    commandString = commandString .. '\''

    commandString = commandString .. ' \'' 
    commandString = commandString .. parametersJSONString
    commandString = commandString .. '\''

    output, status, exitType, rc = hs.execute(commandString)
    outputTable = hs.json.decode(output)
    return outputTable
end
