local nk = require("nakama")

local M = {}

function M.match_init(context, params)
  local state = {
    presences = {},
    numPlayers = 0,
    maxPlayers = params.maxPlayers
  }
  local tickrate = 1 -- per sec, must be set between 1 and 30, inclusive
  local label = params.label
  return state, tickrate, label
end

function M.match_join_attempt(context, dispatcher, tick, state, presence, metadata)
  local acceptuser = false
  nk.logger_debug(string.format("Match Joing Attempt %s", presence.user_id))
  if state.maxPlayers > state.numPlayers then
    state.numPlayers = state.numPlayers + 1
    nk.logger_debug(string.format("number of players %s", state.numPlayers))
    acceptuser = true
  end

  return state, acceptuser
end

function M.match_join(context, dispatcher, tick, state, presences)
  for _, presence in ipairs(presences) do
    state.presences[presence.session_id] = presence
  end
  return state
end

function M.match_leave(context, dispatcher, tick, state, presences)
  for _, presence in ipairs(presences) do
    nk.logger_debug(string.format("Match Leave: %s", presence.user_id))
    state.numPlayers = state.numPlayers - 1
    nk.logger_debug(string.format("Number of players in match: %s", state.numPlayers))
    state.presences[presence.session_id] = nil
  end
  return state
end

local function isNotEmpty(s)
  return s ~= nil and s ~= ''
end

function M.match_loop(context, dispatcher, tick, state, messages)
  -- Messages format:
  -- {
  --   {
  --     sender = {
  --       user_id = "user unique ID",
  --       session_id = "session ID of the user's current connection",
  --       username = "user's unique username",
  --       node = "name of the Nakama node the user is connected to"
  --     },
  --     op_code = 1, -- numeric op code set by the sender.
  --     data = "any string data set by the sender" -- may be nil.
  --   },
  --   ...
  -- }
  -- list of clients to send data to that doesn't include the sender
  local msgTargets = {}
  -- for _, presence in pairs(state.presences) do
  --   nk.logger_debug(string.format("Presence %s named %s", presence.user_id, presence.username))
  -- end
  for _, message in ipairs(messages) do
    nk.logger_debug(string.format("Received %s from %s (%s) (opcode=%s)", message.data, message.sender.username, 
      message.sender.user_id, message.op_code))

    if isNotEmpty(message.data) then
      local decoded = nk.json_decode(message.data)
    end
      -- for k, v in pairs(decoded) do
      --   nk.logger_debug(string.format("Message key %s contains value %s", k, v))
      -- end
      -- PONG message back to sender
      -- dispatcher.broadcast_message(1, message.data, {message.sender})
      -- dispatcher.broadcast_message(1, message.data)
    for _, presence in pairs(state.presences) do
      if message.sender.user_id ~= presence.user_id then
            table.insert(msgTargets, presence)
            nk.logger_debug(string.format("Added %s to targets", presence.user_id))
      end
    end
    if table.getn(msgTargets) > 0 then
      dispatcher.broadcast_message(message.op_code, message.data, msgTargets)
    end

  end
  return state
end

function M.match_terminate(context, dispatcher, tick, state, grace_seconds)
  local message = "Server shutting down in " .. grace_seconds .. " seconds"
  dispatcher.broadcast_message(1, message)
  return nil
end

return M
