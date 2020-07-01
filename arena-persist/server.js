#!/usr/bin/env node
'use strict';

const config = require('./config.json');
const mongoose = require('mongoose');
const mqtt = require('async-mqtt');
const express = require('express');
const {setIntervalAsync} = require('set-interval-async/dynamic');
const {clearIntervalAsync} = require('set-interval-async');


const arenaSchema = new mongoose.Schema({
    object_id: {type: String, required: true, index: true, unique: true},
    attributes: Object,
    expireAt: {type: Date, expires: 0},
    realm: {type: String, required: true, index: true},
    sceneId: {type: String, required: true, index: true},
}, {
    timestamps: true,
});

const ArenaObject = mongoose.model('ArenaObject', arenaSchema);
mongoose.connection.collections.arenaobjects.createIndex({'attributes.parent': 1}, {sparse: true});

let mqttClient;
let persists = new Set();
let expirations;
let expireTimer;

mongoose.connect(config.mongodb.uri, {
    useNewUrlParser: true,
    useFindAndModify: false,
    useCreateIndex: true,
    useUnifiedTopology: true
}).then(async () => {
    console.log('Connected to Mongodb');
    persists = new Set((await ArenaObject.find({}, {'object_id': 1, '_id': 0})).map(o => o.object_id));
    await runMQTT();
    runExpress();
}, err => {
    console.log('Mongodb Connection Error: ', err);
});


async function runMQTT() {
    mqttClient = await mqtt.connectAsync(config.mqtt.uri, {
        clientId: 'arena_persist' + config.mqtt.topic_realm + '_' + Math.floor(Math.random() * 100),
        clean: false, // Receive QoS 1+ messages (object delete) always
        qos: 1,
        will: {
            topic: config.mqtt.statusTopic,
            payload: 'Persistence service disconnected: ' + config.mqtt.topic_realm
        }
    });
    const SCENE_TOPICS = config.mqtt.topic_realm + '/s/#';
    console.log('Connected to MQTT');
    mqttClient.on('offline', async () => {
        if (expireTimer) {
            await clearIntervalAsync(expireTimer);
        }
        console.log('offline, timer off');
    });
    mqttClient.on('reconnect', () => {
        console.log('reconnect');
    });
    mqttClient.on('connect', () => {
        console.log('connect');
    });
    mqttClient.on('disconnect', () => {
        console.log('disconnect');
    });
    mqttClient.on('error', (err) => {
        console.log('error');
        console.log(err);
    });
    try {
        await mqttClient.subscribe(SCENE_TOPICS, {
            qos: 1
        }).then(async () => {
            expirations = new Map();
            if (expireTimer) {
                await clearIntervalAsync(expireTimer);
            }
            expireTimer = setIntervalAsync(publishExpires, 1000);
            await mqttClient.publish(config.mqtt.statusTopic, 'Persistence service connected: ' + config.mqtt.topic_realm);
        });
        mqttClient.on('message', async (topic, message) => {
            let topicSplit = topic.split('/');
            /*
            Topic tokens by forward slash:
            - 0: realm
            - 1: type [s, n, r, topology, flows]
            - 2: scene_id
            */
            let msgJSON;
            let arenaObj;
            let now = new Date();
            let isTemplateMsg = false;
            try {
                msgJSON = JSON.parse(message.toString());
                arenaObj = new ArenaObject({
                    object_id: msgJSON.object_id,
                    attributes: msgJSON.data,
                    expireAt: undefined,
                    realm: topicSplit[0],
                    sceneId: topicSplit[2]
                });
                if (arenaObj.sceneId[0] === '@') {
                    isTemplateMsg = true;
                }
                if (msgJSON.ttl) {
                    if (!isTemplateMsg) {  // Don't expire template scene objects on save
                        arenaObj.expireAt = new Date(now.getTime() + (msgJSON.ttl * 1000));
                    }
                    msgJSON.persist = true;
                }
            } catch (e) {
                return;
            }
            let insertObj = arenaObj.toObject();
            delete insertObj._id;
            switch (msgJSON.action) {
                case 'create':
                    if (msgJSON.persist === true) {
                        await ArenaObject.findOneAndUpdate({object_id: arenaObj.object_id}, insertObj, {
                            upsert: true,
                            runValidators: true
                        });
                        if (arenaObj.expireAt) {
                            expirations.set(arenaObj.object_id, arenaObj);
                        }
                        persists.add(arenaObj.object_id);
                    }
                    break;
                case 'update':
                    if (msgJSON.persist && msgJSON.persist !== false) {
                        if (persists.has(arenaObj.object_id)) {
                            if (msgJSON.type === 'overwrite') {
                                await ArenaObject.findOneAndReplace(
                                    {object_id: insertObj.object_id},
                                    insertObj,
                                    {},
                                    (err) => {
                                        if (err) {
                                            console.log('Does not exist:', arenaObj.object_id);
                                        }
                                    }
                                );
                            } else {
                                await ArenaObject.findOneAndUpdate(
                                    {object_id: arenaObj.object_id},
                                    {$set: flatten({attributes: insertObj.attributes})},
                                    {},
                                    (err) => {
                                        if (err) {
                                            console.log('Does not exist:', arenaObj.object_id);
                                        }
                                    }
                                );
                            }
                            if (arenaObj.expireAt) {
                                expirations.set(arenaObj.object_id, arenaObj);
                            }
                        }
                    }
                    break;
                case 'delete':
                    if (persists.has(arenaObj.object_id)) {
                        await ArenaObject.deleteOne({object_id: arenaObj.object_id}, (err) => {
                            if (err) {
                                console.log('Does not exist or already deleted:', arenaObj.object_id);
                            }
                        });
                        await ArenaObject.deleteMany({'attributes.parent': arenaObj.object_id});
                        if (expirations.has(arenaObj.object_id)) {
                            expirations.delete(arenaObj.object_id);
                        }
                        if (arenaObj.object_id.split('::').length - 1 === 1) {  // Template container ID, 1 pair of '::'
                            let r = RegExp('^' + arenaObj.object_id + '::');
                            await ArenaObject.deleteMany({'attributes.parent': r});
                        }
                        persists.delete(arenaObj.object_id);
                    }
                    break;
                case 'loadTemplate':
                    let a = arenaObj.attributes;
                    let opts = {
                        ttl: a.ttl,
                        persist: a.persist,
                        pose: {
                            position: a.position,
                            rotation: a.rotation
                        }
                    };
                    if (a.templateId) { // make sure template isn't empty exists
                        if (await ArenaObject.countDocuments({sceneId: '@' + a.templateId}) === 0) {
                            return;
                        }
                    }
                    if (a.instanceId) {
                        if (await ArenaObject.countDocuments({
                            sceneId: arenaObj.sceneId,
                            object_id: a.templateId + '::' + a.instanceId
                        }) > 0) {
                            return;
                        }
                    }
                    await loadTemplate(a.instanceId, a.templateId, arenaObj.realm, arenaObj.sceneId, opts);
                    break;
                default:
                //pass
            }
        });
    } catch (e) {
        console.log(e.stack);
    }
}


const createArenaObj = async (object_id, realm, sceneId, attributes, persist, ttl) => {
    let topic = realm + '/s/' + sceneId;
    let expireAt;
    let msg = {
        object_id: object_id,
        action: 'create',
        data: attributes
    };
    if (persist || ttl) {
        msg.persist = true;
    }
    if (ttl) {
        msg.ttl = ttl;
        expireAt = new Date(new Date().getTime() + (ttl * 1000));
    }
    let arenaObj = new ArenaObject({
        object_id: object_id,
        attributes: attributes,
        expireAt: expireAt,
        realm: realm,
        sceneId: sceneId
    }).toObject;
    await ArenaObject.findOneAndUpdate({object_id: object_id}, arenaObj, {
        upsert: true,
    });
    await mqttClient.publish(topic, JSON.stringify(msg));
};


const loadTemplate = async (instanceId, templateId, realm, targetSceneId, opts) => {
    let sceneObjs = await ArenaObject.find({sceneId: '@' + templateId});
    let default_opts = {
        ttl: undefined,
        persist: false,
        attributes: {
            position: {x: 0, y: 0, z: 0},
            rotation: {x: 0, y: 0, z: 0, w: 0},
            object_type: 'templateContainer'
        },
    };
    let options = Object.assign(default_opts, opts);
    let prefix = templateId + '::' + instanceId;
    await createArenaObj(prefix, realm, targetSceneId, options.pose, options.persist, options.ttl);
    await asyncForEach(sceneObjs, async (obj) => {
        if (obj.attributes.parent) {
            obj.attributes.parent = prefix + '::' + obj.attributes.parent;
        } else {
            obj.attributes.parent = prefix;
        }
        await createArenaObj(prefix + '::' + obj.object_id, realm, targetSceneId, obj.attributes,
            options.persist, obj.attributes.ttl);
    });
};


const publishExpires = async () => {
    let now = new Date();
    await asyncMapForEach(expirations, async (obj, key) => {
        if (obj.expireAt < now) {
            let topic = obj.realm + '/s/' + obj.sceneId;
            let msg = {
                object_id: obj.object_id,
                action: 'delete'
            };
            await mqttClient.publish(topic, JSON.stringify(msg));
            expirations.delete(key);
            persists.delete(key);
            await ArenaObject.deleteMany({'attributes.parent': obj.object_id});
        }
    });
};


async function asyncForEach(array, callback) {
    for (let index = 0; index < array.length; index++) {
        await callback(array[index], index, array);
    }
}

async function asyncMapForEach(m, callback) {
    for (let e of m.entries()) {
        await callback(e[1], e[0]);
    }
}

let isPlainObj = (o) => Boolean(
    o && o.constructor && o.constructor.prototype && o.constructor.prototype.hasOwnProperty('isPrototypeOf')
);

let flatten = (obj, keys = []) => {
    return Object.keys(obj).reduce((acc, key) => {
        return Object.assign(acc, isPlainObj(obj[key]) ? flatten(obj[key], keys.concat(key)) : {
            [keys.concat(key).join('.')]: obj[key]
        });
    }, {});
};


const runExpress = () => {
    const app = express();
    app.get('/persist/:sceneId', (req, res) => {
        let now = new Date();
        ArenaObject.find({sceneId: req.params.sceneId, expireAt: {$not: {$lt: now}}},
            {_id: 0, realm: 0, sceneId: 0, __v: 0}
        )
            .then(msgs => {
                res.json(msgs);
            });
    });
    app.get('/persist/:sceneId/:objectId', (req, res) => {
        let now = new Date();
        ArenaObject.find({
                sceneId: req.params.sceneId,
                object_id: req.params.objectId,
                expireAt: {$not: {$lt: now}}
            }, {_id: 0, realm: 0, sceneId: 0, __v: 0}
        ).then(msgs => {
            res.json(msgs);
        });
    });
    app.listen(8884);
};
