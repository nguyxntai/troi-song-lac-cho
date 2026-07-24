extends RefCounted
class_name Currency

## Hiển thị tiền thống nhất theo tiền Việt, có dấu phân tách hàng nghìn.
static func format_vnd(amount: int) -> String:
	var digits := str(absi(amount))
	var grouped := ""
	for index in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0:
			grouped += "."
		grouped += digits[index]
	return ("-" if amount < 0 else "") + grouped + " VND"
