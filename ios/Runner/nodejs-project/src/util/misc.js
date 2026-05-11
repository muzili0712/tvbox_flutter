const charStr = 'abacdefghjklmnopqrstuvwxyzABCDEFGHJKLMNOPQRSTUVWXYZ0123456789';

function rand(min, max) {
    return Math.floor(Math.random() * (max - min + 1)) + min;
}

function randStr(len, withNum, onlyNum) {
    var _str = '';
    let containsNum = withNum === undefined ? true : withNum;
    for (var i = 0; i < len; i++) {
        let idx = onlyNum ? rand(charStr.length - 10, charStr.length - 1) : rand(0, containsNum ? charStr.length - 1 : charStr.length - 11);
        _str += charStr[idx];
    }
    return _str;
}

function randUUID() {
    return randStr(8).toLowerCase() + '-' + randStr(4).toLowerCase() + '-' + randStr(4).toLowerCase() + '-' + randStr(4).toLowerCase() + '-' + randStr(12).toLowerCase();
}

function randMAC() {
    return randStr(2).toUpperCase() + ':' + randStr(2).toUpperCase() + ':' + randStr(2).toUpperCase() + ':' + randStr(2).toUpperCase() + ':' + randStr(2).toUpperCase() + ':' + randStr(2).toUpperCase();
}

const deviceBrands = ['Huawei', 'Xiaomi'];
const deviceModels = [
    ['MHA-AL00', 'HUAWEI Mate 9', 'MHA-TL00', 'HUAWEI Mate 9'],
    ['M2001J2C', 'Xiaomi 10', 'M2011K2C', 'Xiaomi 11'],
];

function randDevice() {
    let brandIdx = rand(0, deviceBrands.length - 1);
    let brand = deviceBrands[brandIdx];
    let modelIdx = rand(0, deviceModels[brandIdx].length / 2 - 1);
    let model = deviceModels[brandIdx][modelIdx * 2 + 1];
    let release = rand(8, 13);
    let buildId = randStr(3, false).toUpperCase() + rand(11, 99) + randStr(1, false).toUpperCase();
    return { brand, model, release, buildId };
}

function randDeviceWithId(len) {
    let device = randDevice();
    device.id = randStr(len);
    return device;
}

function formatPlayUrl(name, title) {
    if (!title) return '';
    title = title.trim();
    if (name && title.startsWith(name)) {
        return title.substring(name.length).replace(/^[\s._-]+/, '');
    }
    return title;
}

function jsonParse(url, data) {
    try {
        if (typeof data === 'string') {
            return JSON.parse(data);
        }
        return data;
    } catch (e) {
        return { url: url };
    }
}

module.exports = {
    rand,
    randStr,
    randUUID,
    randMAC,
    randDevice,
    randDeviceWithId,
    formatPlayUrl,
    jsonParse,
};
