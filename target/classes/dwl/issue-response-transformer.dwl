%dw 2.0
import * from dw::core::Dates
import * from dw::util::Coercions
output application/json

// Safe date parsing function to handle JIRA date strings with various timezone formats
fun safeDateParse(dateStr) = 
    if (dateStr != null and dateStr != "") 
        toDateTimeOrNull(dateStr, [
            {format: "uuuu-MM-dd'T'HH:mm:ss.SSSZ"},      // 2025-08-10T13:59:26.433+0530
            {format: "uuuu-MM-dd'T'HH:mm:ssZ"},          // 2025-08-10T13:59:26+0530
            {format: "uuuu-MM-dd'T'HH:mm:ss.SSS'Z'"},    // 2025-08-10T13:59:26.433Z
            {format: "uuuu-MM-dd'T'HH:mm:ss'Z'"},        // 2025-08-10T13:59:26Z
            {format: "uuuu-MM-dd'T'HH:mm:ss.SSSX"},      // 2025-08-10T13:59:26.433+05:30
            {format: "uuuu-MM-dd'T'HH:mm:ssX"}           // 2025-08-10T13:59:26+05:30
        ])
    else 
        null

---
{
	"success": true,
	"issue": {
		"id": payload.id,
		"key": payload.key,
		"issuetype": payload.fields.issuetype.name default "task/subtask",
		"created": safeDateParse(payload.fields.created),
		"updated": safeDateParse(payload.fields.updated),
		"priority": payload.fields.priority.name default "Medium",
		"status": payload.fields.status.name default "To Do",
		"summary": payload.fields.summary,
		"description": payload.fields.description,
		"assignee": payload.fields.assignee.displayName default null,
		"reporter": payload.fields.reporter.displayName default null,
		"project": {
			"id": payload.fields.project.id,
			"key": payload.fields.project.key,
			"name": payload.fields.project.name
		}
	},
	"timestamp": now()
}