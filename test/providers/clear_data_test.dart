import 'package:apidash/consts.dart';
import 'package:apidash/dashbot/providers/chat_viewmodel.dart';
import 'package:apidash/providers/providers.dart';
import 'package:apidash/services/hive_services.dart';
import 'package:apidash/services/shared_preferences_services.dart';
import 'package:apidash_core/apidash_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/history_models.dart';
import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Clear Data removes persisted data and active state', () async {
    SharedPreferences.setMockInitialValues({});
    await testSetUpTempDirForHive();
    final container = createContainer();
    final collection = container.read(collectionStateNotifierProvider.notifier);
    final environments = container.read(
      environmentsStateNotifierProvider.notifier,
    );
    await Future<void>.delayed(Duration.zero);

    await container
        .read(settingsProvider.notifier)
        .update(
          isDark: true,
          workspaceFolderPath: '/tmp/apidash-clear-data-test',
        );
    await setOnboardingStatusToSharedPrefs(isOnboardingComplete: true);
    container.read(userOnboardedProvider.notifier).state = true;
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
    environments.addEnvironment();
    final customEnvironmentId = container.read(
      selectedEnvironmentIdStateProvider,
    )!;
    environments.updateEnvironment(
      customEnvironmentId,
      values: const [
        EnvironmentVariableModel(key: 'token', value: 'secret', enabled: true),
      ],
    );
    container.read(activeEnvironmentIdStateProvider.notifier).state =
        customEnvironmentId;
    collection.addRequestModel(const HttpRequestModel(url: '{{baseUrl}}/get'));
    await collection.saveData();
    await environments.saveEnvironments();

    await hiveHandler.setHistoryIds([historyMetaModel1.historyId]);
    await hiveHandler.setHistoryMeta(
      historyMetaModel1.historyId,
      historyMetaModel1.toJson(),
    );
    await hiveHandler.setHistoryRequest(
      historyMetaModel1.historyId,
      historyRequestModel1.toJson(),
    );
    await container
        .read(historyMetaStateNotifier.notifier)
        .loadHistoryRequest(historyMetaModel1.historyId);
    await hiveHandler.saveDashbotMessages('saved conversation');
    await container
        .read(chatViewmodelProvider.notifier)
        .sendMessage(text: 'hello');
    container
        .read(terminalStateProvider.notifier)
        .logSystem(category: 'test', message: 'saved request');
    container.read(showTerminalBadgeProvider.notifier).state = true;

    expect(
      container.read(environmentSequenceProvider),
      contains(customEnvironmentId),
    );
    expect(container.read(historyMetaStateNotifier), isNotNull);
    expect(
      container.read(selectedHistoryIdStateProvider),
      historyMetaModel1.historyId,
    );
    expect(container.read(chatViewmodelProvider).chatSessions, isNotEmpty);
    expect(container.read(terminalStateProvider).entries, isNotEmpty);
    expect(await getSettingsFromSharedPrefs(), isNotNull);
    expect(await getOnboardingStatusFromSharedPrefs(), isTrue);

    await collection.clearData();

    expect(collection.state, isEmpty);
    expect(container.read(requestSequenceProvider), isEmpty);
    expect(hiveHandler.dataBox.isEmpty, isTrue);
    expect(hiveHandler.environmentBox.isEmpty, isTrue);
    expect(hiveHandler.historyMetaBox.isEmpty, isTrue);
    expect(hiveHandler.historyLazyBox.isEmpty, isTrue);
    expect(hiveHandler.dashBotBox.isEmpty, isTrue);
    expect(
      container
          .read(environmentsStateNotifierProvider)![kGlobalEnvironmentId]!
          .values,
      isEmpty,
    );
    expect(container.read(environmentSequenceProvider), [kGlobalEnvironmentId]);
    expect(
      container.read(selectedEnvironmentIdStateProvider),
      kGlobalEnvironmentId,
    );
    expect(container.read(activeEnvironmentIdStateProvider), isNull);
    expect(
      collection
          .getSubstitutedHttpRequestModel(
            const HttpRequestModel(url: '{{baseUrl}}/get'),
          )
          .url,
      '{{baseUrl}}/get',
    );
    expect(container.read(historyMetaStateNotifier), isNull);
    expect(container.read(selectedHistoryIdStateProvider), isNull);
    expect(container.read(selectedHistoryRequestModelProvider), isNull);
    expect(container.read(chatViewmodelProvider).chatSessions, isEmpty);
    expect(container.read(terminalStateProvider).entries, isEmpty);
    expect(container.read(showTerminalBadgeProvider), isFalse);
    expect(container.read(settingsProvider).isDark, isFalse);
    expect(
      container.read(settingsProvider).workspaceFolderPath,
      '/tmp/apidash-clear-data-test',
    );
    expect(await getSettingsFromSharedPrefs(), isNull);
    expect(await getOnboardingStatusFromSharedPrefs(), isFalse);
    expect(container.read(userOnboardedProvider), isFalse);
    expect(container.read(hasUnsavedChangesProvider), isFalse);

    await collection.saveData();
    await environments.saveEnvironments();
    expect(hiveHandler.getEnvironment(kGlobalEnvironmentId)['values'], isEmpty);
    expect(hiveHandler.historyMetaBox.isEmpty, isTrue);
    expect(hiveHandler.dashBotBox.isEmpty, isTrue);
  });
}
