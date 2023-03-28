import { hubState } from './hubState.js';
import { Hub } from './hub.js';
document.getElementsByTagName('title')[0].innerText = 'Nellstare HUB';
const rootElement = document.getElementsByTagName('body')[0];
ReactDOM.unmountComponentAtNode(rootElement);
ReactDOM.render( /*#__PURE__*/React.createElement(Hub, {
  state: hubState
}), rootElement);
