import 'package:flutter/material.dart';

class UserAgreementPage extends StatelessWidget {
  const UserAgreementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('用户协议', style: TextStyle(fontWeight: FontWeight.w300)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '用户协议',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '更新日期：2026年5月5日',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            const Text(
              '一、服务条款的确认',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '欢迎使用时纪流（以下简称"本应用"）。在使用本应用之前，请您仔细阅读本用户协议。一旦您开始使用本应用，即表示您已充分理解并同意接受本协议的所有内容。',
              style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.6),
            ),
            const SizedBox(height: 24),
            const Text(
              '二、服务内容',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '1. 本应用致力于为用户提供简洁高效的个人日程管理服务。\n\n'
              '2. 主要服务功能包括：\n'
              '• 日历视图展示日程\n'
              '• 拍照识别自动解析日程\n'
              '• 群组共享与协同安排\n'
              '• 多端数据同步\n\n'
              '3. 我们有权根据业务发展需要调整服务内容。',
              style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.6),
            ),
            const SizedBox(height: 24),
            const Text(
              '三、用户注册与账户',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '1. 用户注册需要提供真实的身份信息。\n\n'
              '2. 用户应当妥善保管自己的账户信息，因个人保管不善造成的损失由用户自行承担。\n\n'
              '3. 用户不得将账户转让、出借给第三方使用。\n\n'
              '4. 用户注销账户后，我们将在15个工作日内删除您的相关数据。',
              style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.6),
            ),
            const SizedBox(height: 24),
            const Text(
              '四、用户行为规范',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '用户在使用本应用时，不得从事以下行为：\n\n'
              '1. 违反法律法规、社会公德的行为。\n\n'
              '2. 侵害他人合法权益的行为。\n\n'
              '3. 干扰本应用正常运营的行为。\n\n'
              '4. 发布违法、有害、骚扰性信息。\n\n'
              '5. 冒充他人或进行虚假宣传。',
              style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.6),
            ),
            const SizedBox(height: 24),
            const Text(
              '五、群组功能规则',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '1. 用户可以创建群组并邀请其他用户加入。\n\n'
              '2. 群组管理员有权管理群组成员和群组日程。\n\n'
              '3. 用户在群组中共享的日程信息仅限群组成员可见。\n\n'
              '4. 群组管理员有权解散群组或移除成员。',
              style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.6),
            ),
            const SizedBox(height: 24),
            const Text(
              '六、知识产权',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '1. 本应用的所有内容，包括但不限于文字、图片、图标、界面设计等，均受知识产权保护。\n\n'
              '2. 用户在使用本应用时发布的原创内容，版权归用户所有。\n\n'
              '3. 用户不得侵犯他人知识产权。',
              style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.6),
            ),
            const SizedBox(height: 24),
            const Text(
              '七、免责声明',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '1. 由于不可抗力导致的服务中断，我们不承担责任。\n\n'
              '2. 用户因个人操作失误导致的数据丢失，我们不承担责任。\n\n'
              '3. 用户在群组中分享的信息，群组其他成员知悉后造成的任何后果，我们不承担责任。\n\n'
              '4. 用户理解并同意，使用本应用产生的任何风险由用户自行承担。',
              style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.6),
            ),
            const SizedBox(height: 24),
            const Text(
              '八、服务变更与终止',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '1. 我们有权在必要时修改服务条款，修改后的条款一旦公布即生效。\n\n'
              '2. 用户如不同意修改后的条款，有权注销账户。\n\n'
              '3. 我们有权在合理情况下终止或暂停服务。',
              style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.6),
            ),
            const SizedBox(height: 24),
            const Text(
              '九、争议解决',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '本协议的解释和执行均适用中华人民共和国法律。如双方发生争议，应友好协商解决；协商不成的，任一方可向有管辖权的人民法院提起诉讼。',
              style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.6),
            ),
            const SizedBox(height: 24),
            const Text(
              '十、联系我们',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '如您对用户协议有任何疑问，请联系我们：\n\n'
              '运营主体：舟山市时纪云人工智能应用软件有限责任公司\n'
              '邮箱：3278904650@qq.com',
              style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.6),
            ),
            const SizedBox(height: 32),
            Center(
              child: Text(
                '© 2026 时纪流 All Rights Reserved',
                style: TextStyle(fontSize: 12, color: Colors.black38),
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}