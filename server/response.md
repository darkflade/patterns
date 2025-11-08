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
    "text": "your_message_content"
  }
}
```
Get
```json
{
  "type": "chat_message",
  "payload": {
    "username": "sender_username",
    "role": "sender_role",
    "text": "sender_text"
  }
}
```
### Roles
```text
"admin",
"moderator",
"peasant"
```
## SFU Handle
All ICE and SDP sending in payload

```json
{
  "type": "ice_candidate/sdp_answer/sdp_offer",
  "payload": "default_webrtc_payload_structure_here"
}
```