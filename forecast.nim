# A simple app for the Blueforcer Awtrix clock to display upcoming rainfall
# Uses Pirate Weather API
# aquova, 2023

import asyncdispatch
import httpclient
import json
import strformat
import os
import tables

import nmqtt

const REQUEST_URL = "https://api.pirateweather.net/forecast"
# NOTE: All of these icons will need to be manually transferred onto the unit
const ICON_TABLE = {
    "cloudy": 52159,
    "partly-cloudy-day": 876,
    "partly-cloudy-night": 2152,
    "clear": 2155,
    "clear-day": 2155,
    "clear-night": 52163,
    "rain": 24095,
    "snow": 24096,
    "sleet": 24096,
    "wind": 2672,
    "fog": 2154
}.toTable()
const DEFAULT_ICON = "clear"

const HEIGHT = 8
const NUM_PRECIP = 11

proc get_data(request: string): JsonNode =
    var client = newHttpClient()
    let response = client.getContent(request)
    let jsonNode = parseJson(response)
    return jsonNode

proc parse_icon(data: JsonNode): int =
    var current_icon = data["currently"]["icon"].getStr()
    if current_icon notin ICON_TABLE:
        current_icon = DEFAULT_ICON
    return ICON_TABLE[current_icon]

proc parse_precip(data: JsonNode): array[NUM_PRECIP, float] =
    for i in 0..<result.len():
        let percentage = data["hourly"]["data"][i]["precipProbability"].getFloat()
        result[i] = percentage

proc send_mqtt(server: string, topics: JsonNode, msg: string) {.async.} =
    let mqtt = newMqttCtx("nmqttClient")
    mqtt.set_host(server, 1883)

    await mqtt.start()
    for topic in topics:
        let topic = topic.getStr()
        await mqtt.publish(topic, msg)
        await sleepAsync(500)
    await mqtt.disconnect()

proc main() =
    let config_filepath = if paramCount() == 1: paramStr(1) else: "config.json"
    if not config_filepath.fileExists():
        echo("Unable to find " & config_filepath)
        return

    let config = parseFile(config_filepath)
    let api_key = config["api"].getStr()
    let lat = config["coords"]["lat"].getStr()
    let long = config["coords"]["long"].getStr()
    let request = &"{REQUEST_URL}/{api_key}/{lat},{long}"

    let data = get_data(request)

    let precip_data = parse_precip(data)
    var converted: array[NUM_PRECIP, int]
    for i, percentage in precip_data.pairs():
        converted[i] = int(percentage * HEIGHT)

    let icon = parse_icon(data)

    let mqtt_server = config["mqtt"]["server"].getStr()
    let mqtt_topics = config["mqtt"]["topics"]
    var j = %*{"icon": icon, "bar": converted, "autoscale": false}
    waitFor send_mqtt(mqtt_server, mqtt_topics, $j)

when isMainModule:
    main()
