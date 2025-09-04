%dw 2.0
import fail from dw::Runtime
output application/json

// Validation function
fun validateRequired(value, fieldName) = 
	if (value == null or value == "") 
		fail("Field '" ++ fieldName ++ "' is required")
	else 
		value

// Get input values with defaults from properties
var projectKey = payload.projectKey default "DEMO"
var summary = payload.summary
var description = payload.description default ""
var issueType = payload.issueType default "Task"
var priority = payload.priority default "Medium"
var assignee = payload.assignee default null
var labels = payload.labels default []
var components = payload.components default []

---
{
	"fields": {
		"project": {
			"key": validateRequired(projectKey, "projectKey")
		},
		"summary": validateRequired(summary, "summary"),
		"description": {
			"type": "doc",
			"version": 1,
			"content": [
				{
					"type": "paragraph",
					"content": [
						{
							"type": "text",
							"text": description
						}
					]
				}
			]
		},
		"issuetype": {
			"name": issueType
		},
		"priority": {
			"name": priority
		}
	} ++ (
		if (assignee != null) 
			{"assignee": {"name": assignee}}
		else 
			{}
	) ++ (
		if (!isEmpty(labels))
			{"labels": labels}
		else
			{}
	) ++ (
		if (!isEmpty(components))
			{"components": components map {"name": $}}
		else
			{}
	)
}