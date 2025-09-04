%dw 2.0
import fail from dw::Runtime
output application/json

// Validation function
fun validateRequired(value, fieldName) = 
	if (value == null or value == "") 
		fail("Field '" ++ fieldName ++ "' is required")
	else 
		value

// Get input values
var key = payload.key
var name = payload.name
var description = payload.description default ""
var projectTypeKey = payload.projectTypeKey default "software"
var leadAccountId = payload.leadAccountId

---
{
	"key": validateRequired(key, "key"),
	"name": validateRequired(name, "name"),
	"description": description,
	"projectTypeKey": projectTypeKey,
	"leadAccountId": validateRequired(leadAccountId, "leadAccountId")
}