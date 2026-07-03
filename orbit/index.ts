// react-native-gesture-handler REQUIRES this to be the very first import of the
// entry file (before anything else, including 'expo'). Having it deeper (in
// App.tsx) can hard-crash release builds at launch.
import 'react-native-gesture-handler';
import { registerRootComponent } from 'expo';
import Root from './src/Root';

registerRootComponent(Root);
