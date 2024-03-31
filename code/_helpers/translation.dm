

/proc/translate(original_string = "UNKNOWN")
	if (config.game_language == "russian")
		if (translations && translations["russian"] && translations["russian"][original_string])
			return translations["russian"][original_string]
		else
			return original_string
	else
		return original_string


var/global/translations = list(
	"russian" = list (
		"test" = "тест",
		"Join Game!" = "Войти в игру"
	)
)