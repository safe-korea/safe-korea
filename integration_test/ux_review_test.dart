// Read-only navigation uses the app's existing data. Screenshot fixtures use
// in-memory stores; no family plan is written and no notification is sent.
import 'inner_layout_test.dart' as inner;
import 'ux_walkthrough_test.dart' as navigation;

void main() {
  inner.main();
  navigation.main();
}
