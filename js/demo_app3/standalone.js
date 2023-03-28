import { DemoApp } from './demoApp.js';
document.getElementsByTagName('title')[0].innerText = 'Nellstare demo page';
const rootElement = document.getElementsByTagName('body')[0];
ReactDOM.render( /*#__PURE__*/React.createElement(DemoApp, null), rootElement);
