import {useHookstate} from '../hookstate.js'
import {demoAppState} from './demoAppState.js'
const {useEffect, useRef} = React;
const Toast = primereact.Toast;
const Button = primereact.Button;
const Card = primereact.Card;

const showMessage = () => {
   demoAppState.show.set(true);
}

const sendReq = async () => {
    let req = new nef.serverRequest(nef.scontrollerUrl);

    req.request = {
        req: 'demo_app.demo_app',
        args: {
            meth: 'say',
            token: nef.getToken()
        }
    }

    let res = await req.send();

   demoAppState.text.set(res.encodedData);
}

const Message = (props) => {
    const state = useHookstate(props.state);
    const visible = state.show.get();
    const messageRef = useRef(null);

    console.log('DemoApp Message:', visible);

    useEffect(() => {
        if (visible == true) {
            messageRef.current.show({severity:'success', summary: 'Message', detail: state.text.get(), life: 3000});
            state.show.set(false);
        }
    }, [visible]);
    
    return (
        <Toast ref={messageRef} />
    )
}

const DemoApp = (props) => {
    return (
        <>
            <Message state={props.state}/>
            <div className="flex justify-content-center align-items-center" style={{height: '100%'}}>
                <Card className="shadow-3" title="Demo Application 1">
                    <div className="formgroup-inline">
                        <div className="field">
                            <Button
                                label="Message"
                                icon="pi pi-bell"
                                className="p-button-lg"
                                onClick={showMessage}
                            />
                        </div>
                        <div className="field">
                        <Button
                            label="Send Req"
                            icon="pi pi-send"
                            className="p-button-lg p-button-secondary"
                            onClick={sendReq}
                        />
                        </div>
                    </div>
                </Card>
            </div>
        </>
    )
}

const demoMenu = [
    {
        label: 'Demo Application 1',
        items: [
            {
                label: 'Send request',
                icon: 'bp bp-send-message',
                command: () => {sendReq()}
            },
            {
                label: 'Show message',
                icon: 'bp bp-notifications-snooze',
                command: showMessage
            }
        ]
    }
    
]

export {
    demoMenu,
    DemoApp
}