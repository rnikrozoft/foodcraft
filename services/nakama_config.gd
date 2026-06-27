extends Node

const HOST := "127.0.0.1"
const PORT := 7350
const SERVER_KEY := "foodcraft_dev_key"
const USE_SSL := false

const BOARD_FAME := "culinary_fame"
const BOARD_EXPLORER := "explorer"

func get_base_url() -> String:
	var scheme := "https" if USE_SSL else "http"
	return "%s://%s:%d" % [scheme, HOST, PORT]
