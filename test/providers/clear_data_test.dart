import 'package:apidash/consts.dart';
import 'package:apidash/providers/providers.dart';
import 'package:apidash/services/hive_services.dart';
import 'package:apidash_core/apidash_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Clear Data removes requests but preserves other saved data', () async {
    await testSetUpTempDirForHive();
    final container = createContainer();
    final collection = container.read(collectionStateNotifierProvider.notifier);
    final environments = container.read(
      environmentsStateNotifierProvider.notifier,
    );
    await Future<void>.delayed(Duration.zero);

    environments.updateEnvironment(
      kGlobalEnvironmentId,
      values: const [
        EnvironmentVariableModel(
          key: 'baseUrl',
          value: 'https://example.com',
          enabled: true,
        ),
      ],
    );
    collection.addRequestModel(const HttpRequestModel(url: '{{baseUrl}}/get'));
    await collection.saveData();
    await environments.saveEnvironments();
    await hiveHandler.setHistoryIds(['history']);
    await hiveHandler.saveDashbotMessages('saved conversation');

    expect(hiveHandler.getIds(), isNotEmpty);

    await collection.clearData();

    expect(collection.state, isEmpty);
    expect(container.read(requestSequenceProvider), isEmpty);
    expect(hiveHandler.getIds(), isNull);
    expect(hiveHandler.getEnvironmentIds(), contains(kGlobalEnvironmentId));
    final savedEnvironment = EnvironmentModel.fromJson(
      Map<String, Object?>.from(
        hiveHandler.getEnvironment(kGlobalEnvironmentId),
      ),
    );
    expect(savedEnvironment.values.single.key, 'baseUrl');
    expect(savedEnvironment.values.single.value, 'https://example.com');
    expect(hiveHandler.getHistoryIds(), ['history']);
    expect(await hiveHandler.getDashbotMessages(), 'saved conversation');
    expect(
      collection
          .getSubstitutedHttpRequestModel(
            const HttpRequestModel(url: '{{baseUrl}}/get'),
          )
          .url,
      'https://example.com/get',
    );
  });
}
