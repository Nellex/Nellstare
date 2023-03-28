import {createState, useHookstate, none} from '../hookstate.js'
const proxyReq = new nef.serverRequest(nef.scontrollerUrl);
proxyReq.request = {
    req: 'proxy.proxy',
    args: {meth: 'proxy_req_js'}
}

const res = await proxyReq.send();
const {startReverse} = await import(res.url);

document.getElementsByTagName('title')[0].innerText = 'Nellstare login page';
const rootElement = document.getElementsByTagName('body')[0];

const Message = primereact.Message;
const InputText = primereact.InputText;
const Password = primereact.Password;
const Button = primereact.Button;
const Card = primereact.Card;

const loginTitle = 'Login'
const loginFailed = (
    <p>
       Login or password incorrect! Please verify your logon credentials and try again.
    </p>
)

const state = createState({
    loginData: '',
    passwordData: '',
    filedLogin: false
})

const sendLoginData = async () => {
    let req = new nef.serverRequest(nef.scontrollerUrl);

    req.request = {
        req: 'auth.auth',
        args: {
            meth: 'login',
            usr: state.loginData.get(),
            passwd:  state.passwordData.get()
        }
    }

    let res = await req.send();

    console.log('LOGIN SEND', res.encodedData);

    if (res.jsonData) {
        nef.setTokens(res.jsonData)
        ReactDOM.unmountComponentAtNode(rootElement);
        startReverse();
    }

    if (res.encodedData && (res.encodedData == 'no arguments!'
        || res.encodedData == 'not authenticated!'
        || res.encodedData == 'duplicated session!'
        || res.encodedData == 'authentication error!')) {
        
        state.merge({
            LoginData: '',
            PasswordData: '',
            filedLogin: true
        })
    }
}

const LoginForm = (props) => {
    const loginData = useHookstate(props.state.loginData);
    const passwordData = useHookstate(props.state.passwordData);
    const filedLogin = useHookstate(props.state.filedLogin);

    const header = (
        <img alt="Logon image" src="images/logo.png"/>
    );

    return (
            <div className="flex justify-content-center align-items-center" style={{ height: '100%', 'min-height': '100vh' }}>
                <Card title={ props.title } className="shadow-3" style={{width: '35em'}} header={header}>
                    <div
                        className="card"
                        onKeyPress={(e) => e.key == 'Enter' ? sendLoginData() : null}
                    >
                        <div className="field">
                            {filedLogin.get() == true ? <Message severity="error" text={props.loginFailedMessage}/> : null}
                        </div>
                        <div className="field col">
                            <span className="p-float-label">
                                <InputText
                                    className="w-full"
                                    id="login-txt"
                                    type="text"
                                    value={loginData.get()}
                                    onChange={(e) => loginData.set(e.target.value)}
                                />
                                <label htmlFor="login-txt">User login</label>
                            </span>
                        </div>
                        <div className="field col">
                            <span className="p-float-label">
                                <Password
                                    inputStyle={{width: '100%'}}
                                    style={{width: '100%'}}
                                    id="password-txt"
                                    feedback={false}
                                    value={passwordData.get()}
                                    onChange={(e) => passwordData.set(e.target.value)}
                                />
                                <label htmlFor="password-txt">Password</label>
                            </span>
                        </div>
                    </div>
                    <div className="flex col justify-content-end">
                        <Button
                            label="Login"
                            icon="pi pi-user"
                            className="p-button-lg"
                            onClick={sendLoginData}
                        />
                    </div>
                    
                </Card>
            </div>
    )
}



ReactDOM.unmountComponentAtNode(rootElement);

ReactDOM.render(<LoginForm
    title={ loginTitle }
    loginFailedMessage={ loginFailed }
    state={state}
/>, rootElement);