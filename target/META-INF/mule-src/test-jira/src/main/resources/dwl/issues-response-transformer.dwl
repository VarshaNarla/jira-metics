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
	"totalIssues": payload.total default 0,
	"issues": (payload.issues default []) map {
		"id": $.id,
		"key": $.key,
		"summary": $.fields.summary,
		"status": $.fields.status.name default "Unknown",
		"priority": $.fields.priority.name default "Medium",
		"created": safeDateParse($.fields.created),
		"updated": safeDateParse($.fields.updated),
		"assignee": $.fields.assignee.displayName default null,
		"project": {
			"id": $.fields.project.id,
			"key": $.fields.project.key,
			"name": $.fields.project.name
		}
	},
	// Add context-specific fields based on variables
	("issueType": vars.issueType) if (vars.issueType != null),
	("status": vars.status) if (vars.status != null),
	("assignee": vars.assignee) if (vars.assignee != null),
	("project": vars.projectId) if (vars.projectId != null),
	("period": "From " ++ vars.fromDaysAgo ++ " to " ++ vars.toDaysAgo ++ " days ago") if (vars.fromDaysAgo != null and vars.toDaysAgo != null),
	"timestamp": now()
}