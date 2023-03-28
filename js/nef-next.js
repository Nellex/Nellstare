let base64 = Base64;
let nef = {
    scontrollerUrl: ''
};

nef.serverRequest = class {
    constructor(url) {
        this.url = url;
        this.recursive = false;
        this.request = {
            req: '',
            args: {meth: ''}
        }
    }
    
    async send() {
        const res = await fetch(this.url, {
            mode: 'same-origin',
            method: 'post',
            headers: {
                'Accept': 'application/json, text/plain',
            },
            body: 'jsonData=' + JSON.stringify(this.request)
        });

        if (res.ok !== true) {
            const reqError = `Request filed, status: ${res.status}.`;
            console.error(`${reqError} Request detail:`, this.request);

            return {raw: reqError}
        }

        const buf = await res.arrayBuffer(); 
        const rawText = new TextDecoder().decode(buf);
        let serverResponse;
        let responseObj = {};

        try {
            serverResponse = JSON.parse(rawText);
        } catch (e) {
            return {raw: rawText}
        }

        if (typeof(serverResponse) == 'boolean') {
            return {raw: serverResponse}
        }

        if (typeof(serverResponse) == 'number') {
            return {raw: serverResponse}
        }

        if (serverResponse.url) {
            responseObj.url = serverResponse.url;
        }

        if (serverResponse.jsonData) {
            responseObj.jsonData = serverResponse.jsonData;
        }

        if (serverResponse.html) {
            responseObj.html = base64.decode(serverResponse.html);
        }

        if (serverResponse.js) {
            responseObj.js = await import(serverResponse.js);
        }

        if (serverResponse.encodedData) {
            responseObj.encodedData = base64.decode(serverResponse.encodedData);
        }

        if (serverResponse.links) {
            responseObj.links = {};

            for (let linkName in serverResponse.links) {
                let linkRequest = serverResponse.links[linkName];
                
                const linkRes = await fetch(this.url, {
                    mode: 'same-origin',
                    method: 'post',
                    headers: {
                        'Accept': '*/*'
                    },
                    body: 'jsonData=' + JSON.stringify(linkRequest)
                });

                if (linkRes.ok !== true) {
                    console.error(`Request filed, status: ${linkRes.status}. Request detail:`, linkRequest);

                    continue
                }

                const linkContent = await linkRes.blob();
                responseObj.links[linkName] = URL.createObjectURL(linkContent);
            }
        }

        return responseObj
    }
}

nef.getToken = function () {
    let a_token = localStorage.getItem('a_token');
    let r_token = localStorage.getItem('r_token');

    if (this.validateToken(a_token)) {
        return a_token
    }

    if (this.validateToken(r_token)) {
        return r_token
    }
}

nef.validateToken = function(token) {
    if (!token) {
        return false
    }

    let now = Math.round(+new Date()/1000);

    token = token.split('.')

    if (token.length !== 2) {
        // console.log('1: invalid token!');
        return false
    }

    try {
        token = JSON.parse(base64.decode(token[0]));
    } catch(e){
        token = {};
    }

    if (!token.exp) {
        // console.log('2: invalid token!');
        return false
    }

    let timeDelta = (Number(token.exp) - now) | 0;
    
    if (timeDelta == 0) {
        // console.log('3: invalid token!');
        return false
    }
    
    if (timeDelta > 59) {
        // console.log(`Time delta: ${timeDelta}`)
        return true
    }
}

nef.setTokens = function(tokens) {
    if (!tokens){
        return false
    }

    if (!tokens.a_token || !tokens.r_token) {
        // console.log('5: invalid token!');
        return false
    }

    if (typeof(tokens.a_token) !== 'string' || typeof(tokens.r_token) !== 'string') {
        // console.log('6: invalid token!');
        return false
    }

    if (!this.validateToken(tokens.a_token) || !this.validateToken(tokens.r_token)) {
        return false
    }

    localStorage.setItem('a_token', tokens.a_token);
    localStorage.setItem('r_token', tokens.r_token);

    return true
}

nef.renewToken = async function() {
    let req = new this.serverRequest(this.scontrollerUrl);

    req.request = {
        req: 'proxy.proxy',
        args: {
            meth: 'chk_token',
            token: this.getToken()
        }
    }

    let res = await req.send();

    if (res.raw && res.raw === 'invalid token!') {
        localStorage.removeItem('a_token');
        localStorage.removeItem('r_token');
        location.reload();

        throw('tokens removed!');
    }

    if (res.jsonData) {
        this.setTokens(res.jsonData);
    }
}

nef.sha256 = async function(input) {
    const textAsBuffer = new TextEncoder().encode(input);
    const hashBuffer = await window.crypto.subtle.digest("SHA-256", textAsBuffer);

    const hashArray = Array.from(new Uint8Array(hashBuffer));
    const hash = hashArray.map((item) => item.toString(16).padStart(2, "0")).join("");

    return hash
}