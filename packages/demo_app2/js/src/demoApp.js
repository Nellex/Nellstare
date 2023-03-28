const {useRef} = React;
const Toast = primereact.Toast;
const Button = primereact.Button;
const Card = primereact.Card;

const DemoApp = () => {
    const msgToast = useRef(null);
    let msg = 'Hello!';

    const showMsg = () => {
        msgToast.current.show({severity:'success', summary: 'Message', detail: msg, life: 3000});
    }

    const sendReq = async () => {
        let req = new nef.serverRequest(nef.scontrollerUrl);

        req.request = {
            req: 'demo_app2.demo_app2',
            args: {
                meth: 'say',
                token: nef.getToken()
            }
        }

        let res = await req.send();

        msg = res.encodedData;
    }

    return (
        <>
            <Toast ref={msgToast} />
            <div className="flex justify-content-center align-items-center" style={{height: '100%'}}>
                <Card className="shadow-3" title="Demo Application 2">
                    <div className="formgroup-inline">
                        <div className="field">
                            <Button
                                label="Message"
                                icon="pi pi-bell"
                                className="p-button-lg"
                                onClick={ showMsg }
                            />
                        </div>
                        <div className="field">
                        <Button
                            label="Send Req"
                            icon="pi pi-send"
                            className="p-button-lg p-button-secondary"
                            onClick={ sendReq }
                        />
                        </div>
                    </div>
                </Card>
            </div>
        </>
    )
}

export {
    DemoApp
}