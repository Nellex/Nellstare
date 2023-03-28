const {
  useRef
} = React;
const Toast = primereact.Toast;
const Button = primereact.Button;
const Card = primereact.Card;

const DemoApp = () => {
  const msgToast = useRef(null);
  let msg = 'Hello!';

  const showMsg = () => {
    msgToast.current.show({
      severity: 'success',
      summary: 'Message',
      detail: msg,
      life: 3000
    });
  };

  const sendReq = async () => {
    let req = new nef.serverRequest(nef.scontrollerUrl);
    req.request = {
      req: 'demo_app4.demo_app4',
      args: {
        meth: 'say',
        token: nef.getToken()
      }
    };
    let res = await req.send();
    msg = res.encodedData;
  };

  return /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(Toast, {
    ref: msgToast
  }), /*#__PURE__*/React.createElement("div", {
    className: "flex justify-content-center alignn-items-center",
    style: {
      height: '100%'
    }
  }, /*#__PURE__*/React.createElement(Card, {
    className: "shadow-3",
    title: "Demo Application 4"
  }, /*#__PURE__*/React.createElement("div", {
    className: "formgroup-inline"
  }, /*#__PURE__*/React.createElement("div", {
    className: "field"
  }, /*#__PURE__*/React.createElement(Button, {
    label: "Message",
    icon: "pi pi-bell",
    className: "p-button-lg",
    onClick: showMsg
  })), /*#__PURE__*/React.createElement("div", {
    className: "field"
  }, /*#__PURE__*/React.createElement(Button, {
    label: "Send Req",
    icon: "pi pi-send",
    className: "p-button-lg p-button-secondary",
    onClick: sendReq
  }))))));
};

export { DemoApp };
