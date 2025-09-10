import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../models/theme_settings.dart';
import '../../services/user_settings_firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class SoundSettingsPage extends StatefulWidget {
  const SoundSettingsPage({super.key});

  @override
  State<SoundSettingsPage> createState() => _SoundSettingsPageState();
}

class _SoundSettingsPageState extends State<SoundSettingsPage> {
  bool _isLoading = true;
  bool _timerSoundEnabled = true;
  bool _notificationSoundEnabled = true;
  double _timerVolume = 0.7;
  double _notificationVolume = 0.5;
  String _selectedTimerSound = 'sounds/alarm/alarm01.mp3';
  String _selectedNotificationSound = 'sounds/notification/notification01.mp3';

  // 現在再生中のAudioPlayerを管理
  AudioPlayer? _currentPlayer;
  bool _isPlaying = false;

  final List<String> _timerSounds = [
    'sounds/alarm/alarm01.mp3',
    'sounds/alarm/alarm02.mp3',
    'sounds/alarm/alarm03.mp3',
    'sounds/alarm/alarm04.mp3',
    'sounds/alarm/alarm05.mp3',
  ];

  final List<String> _notificationSounds = [
    'sounds/notification/notification01.mp3',
    'sounds/notification/notification02.mp3',
    'sounds/notification/notification03.mp3',
    'sounds/notification/notification04.mp3',
    'sounds/notification/notification05.mp3',
  ];

  @override
  void initState() {
    super.initState();
    _loadSoundSettings();
    _loadSoundSettingsFromFirestore();
    _startSoundSettingsListener();
  }

  Future<void> _loadSoundSettingsFromFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('sound')
        .get();
    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      setState(() {
        _timerSoundEnabled = data['alarmEnabled'] ?? true;
        _notificationSoundEnabled = data['notificationEnabled'] ?? true;
        _timerVolume = (data['alarmVolume'] as num?)?.toDouble() ?? 0.7;
        _notificationVolume =
            (data['notificationVolume'] as num?)?.toDouble() ?? 0.5;
        _selectedTimerSound = data['alarmSound'] ?? 'sounds/alarm/alarm01.mp3';
        _selectedNotificationSound =
            data['notificationSound'] ??
            'sounds/notification/notification01.mp3';
      });
    }
  }

  StreamSubscription? _soundSettingsSubscription;
  void _startSoundSettingsListener() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _soundSettingsSubscription?.cancel();
    _soundSettingsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('sound')
        .snapshots()
        .listen((doc) {
          if (doc.exists && doc.data() != null) {
            final data = doc.data()!;
            setState(() {
              _timerSoundEnabled = data['alarmEnabled'] ?? true;
              _notificationSoundEnabled = data['notificationEnabled'] ?? true;
              _timerVolume = (data['alarmVolume'] as num?)?.toDouble() ?? 0.7;
              _notificationVolume =
                  (data['notificationVolume'] as num?)?.toDouble() ?? 0.5;
              _selectedTimerSound =
                  data['alarmSound'] ?? 'sounds/alarm/alarm01.mp3';
              _selectedNotificationSound =
                  data['notificationSound'] ??
                  'sounds/notification/notification01.mp3';
            });
          }
        });
  }

  @override
  void dispose() {
    // ページを離れる際に再生中の音声を停止
    _stopCurrentSound();
    _soundSettingsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadSoundSettings() async {
    try {
      final timerSoundEnabled = await UserSettingsFirestoreService.getSetting(
        'timer_sound_enabled',
        defaultValue: true,
      );
      final notificationSoundEnabled =
          await UserSettingsFirestoreService.getSetting(
            'notification_sound_enabled',
            defaultValue: true,
          );
      final timerVolume = await UserSettingsFirestoreService.getSetting(
        'timer_volume',
        defaultValue: 0.7,
      );
      final notificationVolume = await UserSettingsFirestoreService.getSetting(
        'notification_volume',
        defaultValue: 0.5,
      );
      final selectedTimerSound = await UserSettingsFirestoreService.getSetting(
        'selected_timer_sound',
        defaultValue: 'sounds/alarm/alarm01.mp3',
      );
      final selectedNotificationSound =
          await UserSettingsFirestoreService.getSetting(
            'selected_notification_sound',
            defaultValue: 'sounds/notification/notification01.mp3',
          );

      setState(() {
        _timerSoundEnabled = timerSoundEnabled;
        _notificationSoundEnabled = notificationSoundEnabled;
        _timerVolume = timerVolume;
        _notificationVolume = notificationVolume;
        _selectedTimerSound = selectedTimerSound;
        _selectedNotificationSound = selectedNotificationSound;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveTimerSoundEnabled(bool value) async {
    await UserSettingsFirestoreService.saveSetting(
      'timer_sound_enabled',
      value,
    );
    setState(() {
      _timerSoundEnabled = value;
    });
  }

  Future<void> _saveNotificationSoundEnabled(bool value) async {
    await UserSettingsFirestoreService.saveSetting(
      'notification_sound_enabled',
      value,
    );
    setState(() {
      _notificationSoundEnabled = value;
    });
  }

  Future<void> _saveTimerVolume(double value) async {
    await UserSettingsFirestoreService.saveSetting('timer_volume', value);
    setState(() {
      _timerVolume = value;
    });
  }

  Future<void> _saveNotificationVolume(double value) async {
    await UserSettingsFirestoreService.saveSetting(
      'notification_volume',
      value,
    );
    setState(() {
      _notificationVolume = value;
    });
  }

  Future<void> _saveSelectedTimerSound(String sound) async {
    await UserSettingsFirestoreService.saveSetting(
      'selected_timer_sound',
      sound,
    );
    setState(() {
      _selectedTimerSound = sound;
    });
  }

  Future<void> _saveSelectedNotificationSound(String sound) async {
    await UserSettingsFirestoreService.saveSetting(
      'selected_notification_sound',
      sound,
    );
    setState(() {
      _selectedNotificationSound = sound;
    });
  }

  String _getTimerSoundDisplayName(String soundFile) {
    switch (soundFile) {
      case 'sounds/alarm/alarm01.mp3':
        return 'デジタル時計1';
      case 'sounds/alarm/alarm02.mp3':
        return 'デジタル時計2';
      case 'sounds/alarm/alarm03.mp3':
        return 'デジタル時計3';
      case 'sounds/alarm/alarm04.mp3':
        return '時計のベル1';
      case 'sounds/alarm/alarm05.mp3':
        return '時計のベル2';
      default:
        return soundFile.replaceAll('.mp3', '');
    }
  }

  String _getNotificationSoundDisplayName(String soundFile) {
    switch (soundFile) {
      case 'sounds/notification/notification01.mp3':
        return '通知1';
      case 'sounds/notification/notification02.mp3':
        return '通知2';
      case 'sounds/notification/notification03.mp3':
        return '通知3';
      case 'sounds/notification/notification04.mp3':
        return '通知4';
      case 'sounds/notification/notification05.mp3':
        return '通知5';
      default:
        return soundFile.replaceAll('.mp3', '');
    }
  }

  Future<void> _stopCurrentSound() async {
    if (_currentPlayer != null) {
      try {
        await _currentPlayer!.stop();
        await _currentPlayer!.dispose();
      } catch (e) {
        debugPrint('音声停止エラー: $e');
      } finally {
        _currentPlayer = null;
        _isPlaying = false;
      }
    }
  }

  void _playTestSound(String soundFile) async {
    // 既に再生中の場合は何もしない
    if (_isPlaying) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    try {
      _isPlaying = true;

      // 既に再生中の音声があれば停止
      await _stopCurrentSound();

      // 新しいAudioPlayerを作成
      _currentPlayer = AudioPlayer();

      // エラーハンドリングを追加
      _currentPlayer!.onPlayerStateChanged.listen((state) {
        if (state == PlayerState.completed) {
          _isPlaying = false;
        } else if (state == PlayerState.stopped) {
          _isPlaying = false;
        }
      });

      // 再生開始（パスを修正）
      await _currentPlayer!.play(AssetSource(soundFile));

      // 3秒後に自動停止
      Future.delayed(const Duration(milliseconds: 3000), () async {
        if (_isPlaying && _currentPlayer != null) {
          await _stopCurrentSound();
        }
      });
    } catch (e) {
      // エラー時のフィードバック
      _isPlaying = false;
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('音声の再生に失敗しました: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('サウンド設定'),
        backgroundColor: themeSettings.appBarColor,
        foregroundColor: themeSettings.appBarTextColor,
      ),
      body: SafeArea(
        child: Container(
          color: themeSettings.backgroundColor,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 600, // Web版での最大幅を制限
                    ),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildTimerSoundSection(themeSettings),
                        const SizedBox(height: 24),
                        _buildNotificationSoundSection(themeSettings),
                        const SizedBox(height: 24),
                        _buildVolumeSection(themeSettings),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildTimerSoundSection(ThemeSettings themeSettings) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: themeSettings.cardBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timer, color: themeSettings.iconColor),
                const SizedBox(width: 8),
                Text(
                  'タイマー音設定',
                  style: TextStyle(
                    fontSize: 18 * themeSettings.fontSizeScale,
                    fontWeight: FontWeight.bold,
                    color: themeSettings.fontColor1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // タイマー音のオン・オフ
            ListTile(
              leading: Icon(
                _timerSoundEnabled ? Icons.volume_up : Icons.volume_off,
                color: _timerSoundEnabled
                    ? Colors.green
                    : themeSettings.iconColor,
              ),
              title: Text(
                'タイマー音',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: themeSettings.fontColor1,
                ),
              ),
              subtitle: Text(
                _timerSoundEnabled ? 'タイマー終了時に音が鳴ります' : 'タイマー音が無効です',
                style: TextStyle(color: themeSettings.fontColor1),
              ),
              trailing: Switch(
                value: _timerSoundEnabled,
                onChanged: _saveTimerSoundEnabled,
                activeThumbColor: themeSettings.buttonColor,
              ),
            ),
            if (_timerSoundEnabled) ...[
              const SizedBox(height: 16),
              // タイマー音の選択
              Text(
                'タイマー音の種類',
                style: TextStyle(
                  fontSize: 16 * themeSettings.fontSizeScale,
                  fontWeight: FontWeight.bold,
                  color: themeSettings.fontColor1,
                ),
              ),
              const SizedBox(height: 8),
              ...(_timerSounds
                  .map(
                    (sound) => Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      color: _selectedTimerSound == sound
                          ? themeSettings.buttonColor.withValues(alpha: 0.1)
                          : themeSettings.cardBackgroundColor,
                      child: ListTile(
                        leading: Icon(
                          _selectedTimerSound == sound
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: _selectedTimerSound == sound
                              ? themeSettings.buttonColor
                              : themeSettings.iconColor,
                        ),
                        title: Text(
                          _getTimerSoundDisplayName(sound),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: themeSettings.fontColor1,
                          ),
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            Icons.play_arrow,
                            color: themeSettings.iconColor,
                          ),
                          onPressed: () => _playTestSound(sound),
                        ),
                        onTap: () => _saveSelectedTimerSound(sound),
                      ),
                    ),
                  )
                  .toList()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationSoundSection(ThemeSettings themeSettings) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: themeSettings.cardBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications, color: themeSettings.iconColor),
                const SizedBox(width: 8),
                Text(
                  '通知音設定',
                  style: TextStyle(
                    fontSize: 18 * themeSettings.fontSizeScale,
                    fontWeight: FontWeight.bold,
                    color: themeSettings.fontColor1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 通知音のオン・オフ
            ListTile(
              leading: Icon(
                _notificationSoundEnabled ? Icons.volume_up : Icons.volume_off,
                color: _notificationSoundEnabled
                    ? Colors.green
                    : themeSettings.iconColor,
              ),
              title: Text(
                '通知音',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: themeSettings.fontColor1,
                ),
              ),
              subtitle: Text(
                _notificationSoundEnabled ? '通知時に音が鳴ります' : '通知音が無効です',
                style: TextStyle(color: themeSettings.fontColor1),
              ),
              trailing: Switch(
                value: _notificationSoundEnabled,
                onChanged: _saveNotificationSoundEnabled,
                activeThumbColor: themeSettings.buttonColor,
              ),
            ),
            if (_notificationSoundEnabled) ...[
              const SizedBox(height: 16),
              // 通知音の選択
              Text(
                '通知音の種類',
                style: TextStyle(
                  fontSize: 16 * themeSettings.fontSizeScale,
                  fontWeight: FontWeight.bold,
                  color: themeSettings.fontColor1,
                ),
              ),
              const SizedBox(height: 8),
              ...(_notificationSounds
                  .map(
                    (sound) => Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      color: _selectedNotificationSound == sound
                          ? themeSettings.buttonColor.withValues(alpha: 0.1)
                          : themeSettings.cardBackgroundColor,
                      child: ListTile(
                        leading: Icon(
                          _selectedNotificationSound == sound
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: _selectedNotificationSound == sound
                              ? themeSettings.buttonColor
                              : themeSettings.iconColor,
                        ),
                        title: Text(
                          _getNotificationSoundDisplayName(sound),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: themeSettings.fontColor1,
                          ),
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            Icons.play_arrow,
                            color: themeSettings.iconColor,
                          ),
                          onPressed: () => _playTestSound(sound),
                        ),
                        onTap: () => _saveSelectedNotificationSound(sound),
                      ),
                    ),
                  )
                  .toList()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVolumeSection(ThemeSettings themeSettings) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: themeSettings.cardBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.volume_up, color: themeSettings.iconColor),
                const SizedBox(width: 8),
                Text(
                  '音量設定',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: themeSettings.fontColor1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // タイマー音量
            if (_timerSoundEnabled) ...[
              Text(
                'タイマー音量',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: themeSettings.fontColor1,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.volume_down, color: themeSettings.iconColor),
                  Expanded(
                    child: Slider(
                      value: _timerVolume,
                      min: 0.0,
                      max: 1.0,
                      divisions: 10,
                      activeColor: themeSettings.buttonColor,
                      inactiveColor: themeSettings.iconColor.withValues(
                        alpha: 0.3,
                      ),
                      onChanged: _saveTimerVolume,
                    ),
                  ),
                  Icon(Icons.volume_up, color: themeSettings.iconColor),
                  const SizedBox(width: 8),
                  Text(
                    '${(_timerVolume * 100).round()}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: themeSettings.fontColor1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            // 通知音量
            if (_notificationSoundEnabled) ...[
              Text(
                '通知音量',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: themeSettings.fontColor1,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.volume_down, color: themeSettings.iconColor),
                  Expanded(
                    child: Slider(
                      value: _notificationVolume,
                      min: 0.0,
                      max: 1.0,
                      divisions: 10,
                      activeColor: themeSettings.buttonColor,
                      inactiveColor: themeSettings.iconColor.withValues(
                        alpha: 0.3,
                      ),
                      onChanged: _saveNotificationVolume,
                    ),
                  ),
                  Icon(Icons.volume_up, color: themeSettings.iconColor),
                  const SizedBox(width: 8),
                  Text(
                    '${(_notificationVolume * 100).round()}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: themeSettings.fontColor1,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
