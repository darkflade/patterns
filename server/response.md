## WS Chat Structure
___
### For WS connect send unique username
```http request
your_host/ws?username=your_username
```
### In ws Messages sends in following format
Send

```json
{
  "type": "chat_message",
  "payload": {
    "text": "<your_message_content>"
  }
}
```
Get
```json
{
  "type": "chat_message",
  "payload": {
    "username": "<sender_username>",
    "role": "<sender_role>",
    "text": "<sender_text>"
  }
}
```
### Roles
```text
"admin"
"moderator"
"peasant"
```
## SFU Handle
All ICE and SDP sending in payload

```json
{
  "type": "ice_candidate/sdp_answer/sdp_offer",
  "payload": "<default_webrtc_payload_structure_here>"
}
```

## Get Connected Clients
### Request
```json
{
  "type": "active_clients_ws"
}   
```

```json
{
  "type": "active_clients_sfu"
}   
```
### Response
```json
{
  "type": "active_clients_ws_response",
  "payload": [
    {
      "username": "<active_client_username>",
      "role" : "<active_client_role>"
    }
  ]
}   
```
```json
{
  "type": "active_clients_sfu_response",
  "payload": [
    {
      "username": "<active_client_username>",
      "role" : "<active_client_role>"
    }
  ]
}   
```

## Change user role _(only admin can do)_
### Request

```json
{
  "type": "promote_user",
  "payload": {
    "username": "<name_of_user_to_change_role>",
    "new_role": "<new_role>"
  }
}
```

# System Messages

## Common System Message

## User Join
### Response
```json 
{
  "type": "user_joined",
  "payload": {
    "username": "<joined_user's_name>",
    "role": "<joined_user's_role>"
  }
}
```
## User Leave
### Response
```json 
{
  "type": "user_left",
  "payload": {
    "username": "<left_user's_name>",
    "role": "<left_user's_role>"
  }
}
```

## System Error
### Response
```json
{
  "type": "system_error_message",
  "payload": {
    "error": "<error_text>"
  }
}
```