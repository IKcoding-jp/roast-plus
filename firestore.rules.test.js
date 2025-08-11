const { initializeTestEnvironment } = require('@firebase/rules-unit-testing');
const { readFileSync } = require('fs');

const PROJECT_ID = 'bysnlogapp';

// テスト環境の設定
const testEnv = await initializeTestEnvironment({
  projectId: PROJECT_ID,
  firestore: {
    rules: readFileSync('firestore.rules', 'utf8'),
  },
});

describe('Firestore Security Rules', () => {
  afterAll(async () => {
    await testEnv.cleanup();
  });

  afterEach(async () => {
    await testEnv.clearFirestore();
  });

  describe('ユーザーコレクション', () => {
    it('認証されたユーザーは自分のデータにアクセスできる', async () => {
      const db = testEnv.authenticatedContext('user1').firestore();
      await firebase.assertSucceeds(
        db.collection('users').doc('user1').set({
          name: 'Test User',
          email: 'test@example.com'
        })
      );
    });

    it('認証されたユーザーは他のユーザーのデータにアクセスできない', async () => {
      const db = testEnv.authenticatedContext('user1').firestore();
      await firebase.assertFails(
        db.collection('users').doc('user2').get()
      );
    });

    it('未認証ユーザーはユーザーデータにアクセスできない', async () => {
      const db = testEnv.unauthenticatedContext().firestore();
      await firebase.assertFails(
        db.collection('users').doc('user1').get()
      );
    });

    it('ユーザーは自分のサブコレクションにアクセスできる', async () => {
      const db = testEnv.authenticatedContext('user1').firestore();
      await firebase.assertSucceeds(
        db.collection('users').doc('user1').collection('settings').doc('theme').set({
          theme: 'dark'
        })
      );
    });
  });

  describe('グループコレクション', () => {
    beforeEach(async () => {
      // テスト用のグループを作成
      const adminDb = testEnv.authenticatedContext('admin').firestore();
      await adminDb.collection('groups').doc('group1').set({
        name: 'Test Group',
        createdBy: 'admin'
      });
      await adminDb.collection('groups').doc('group1').collection('members').doc('admin').set({
        role: 'admin',
        joinedAt: new Date()
      });
    });

    it('グループメンバーはグループデータを読み取れる', async () => {
      const memberDb = testEnv.authenticatedContext('member').firestore();
      // メンバーをグループに追加
      const adminDb = testEnv.authenticatedContext('admin').firestore();
      await adminDb.collection('groups').doc('group1').collection('members').doc('member').set({
        role: 'member',
        joinedAt: new Date()
      });

      await firebase.assertSucceeds(
        memberDb.collection('groups').doc('group1').get()
      );
    });

    it('グループメンバーでないユーザーはグループデータにアクセスできない', async () => {
      const nonMemberDb = testEnv.authenticatedContext('nonmember').firestore();
      await firebase.assertFails(
        nonMemberDb.collection('groups').doc('group1').get()
      );
    });

    it('グループ管理者のみがグループデータを更新できる', async () => {
      const adminDb = testEnv.authenticatedContext('admin').firestore();
      await firebase.assertSucceeds(
        adminDb.collection('groups').doc('group1').update({
          name: 'Updated Group Name'
        })
      );
    });

    it('一般メンバーはグループデータを更新できない', async () => {
      const memberDb = testEnv.authenticatedContext('member').firestore();
      // メンバーをグループに追加
      const adminDb = testEnv.authenticatedContext('admin').firestore();
      await adminDb.collection('groups').doc('group1').collection('members').doc('member').set({
        role: 'member',
        joinedAt: new Date()
      });

      await firebase.assertFails(
        memberDb.collection('groups').doc('group1').update({
          name: 'Unauthorized Update'
        })
      );
    });
  });

  describe('システムコレクション', () => {
    it('認証されたユーザーはシステム設定を読み取れる', async () => {
      const db = testEnv.authenticatedContext('user1').firestore();
      await firebase.assertSucceeds(
        db.collection('system').doc('config').get()
      );
    });

    it('認証されたユーザーでもシステム設定を書き込めない', async () => {
      const db = testEnv.authenticatedContext('user1').firestore();
      await firebase.assertFails(
        db.collection('system').doc('config').set({
          setting: 'value'
        })
      );
    });
  });

  describe('その他のコレクション', () => {
    it('未定義のコレクションにはアクセスできない', async () => {
      const db = testEnv.authenticatedContext('user1').firestore();
      await firebase.assertFails(
        db.collection('unknown').doc('doc1').get()
      );
    });
  });
});
