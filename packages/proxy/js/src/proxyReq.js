const startLogin = async () => {
    let login = new nef.serverRequest(nef.scontrollerUrl);
    login.request = {
        req: 'login.login',
        args: {reverse_route: reverseRoute}
    }

    let res = await login.send();

    if (!res.js) {
        return console.error('error loading login package')
    }
}

const startReverse = async () => {
    let reverse = new nef.serverRequest(nef.scontrollerUrl);
    reverse.request = {
        req: reverseRoute,
        args: {token: nef.getToken()}
    }
    
    await reverse.send();
}

let proxyInit = function(){
    let token = nef.getToken();

    if (!token){
        startLogin();
    }

    startReverse();
}

export {
    startLogin,
    startReverse,
    proxyInit
}