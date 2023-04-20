# A simple app for the Blueforcer Awtrix clock to display upcoming rainfall
# Uses Pirate Weather API
# aquova, 2023

import asyncdispatch
import httpclient
import json
import strformat
import os

import nmqtt

const REQUEST_URL = "https://api.pirateweather.net/forecast"

const ICON = 24095
const HEIGHT = 8
const NUM_PRECIP = 11

proc get_precip(request: string): array[NUM_PRECIP, float] =
    var client = newHttpClient()
    let response = client.getContent(request)
    let jsonNode = parseJson(response)
    for i in 0..<result.len():
        let percentage = jsonNode["hourly"]["data"][i]["precipProbability"].getFloat()
        result[i] = percentage

proc send_mqtt(server, topic, msg: string) {.async.} =
    let mqtt = newMqttCtx("nmqttClient")
    mqtt.set_host(server, 1883)

    await mqtt.start()
    await mqtt.publish(topic, msg)
    await sleepAsync(500)
    await mqtt.disconnect()

proc main() =
    let config_filepath = if paramCount() == 1: paramStr(1) else: "config.json"
    let config = parseFile(config_filepath)
    let api_key = config["api"].getStr()
    let lat = config["coords"]["lat"].getStr()
    let long = config["coords"]["long"].getStr()
    let request = &"{REQUEST_URL}/{api_key}/{lat},{long}"

    let data = get_precip(request)
    var converted: array[NUM_PRECIP, int]
    for i, percentage in data.pairs():
        converted[i] = int(percentage * HEIGHT)

    let mqtt_server = config["mqtt"]["server"].getStr()
    let mqtt_topic = config["mqtt"]["topic"].getStr()
    var j = %*{"icon": ICON, "bar": converted, "autoscale": false}
    waitFor send_mqtt(mqtt_server, mqtt_topic, $j)

when isMainModule:
    main()
