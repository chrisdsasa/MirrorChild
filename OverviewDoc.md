我们在做一个iOS App 用Swift 和 swiftUI 我们的想法是要做一个iOS的APP， 这个是一个数字人子女。用来陪伴留守老人，然后可以实时查看 手机 的 share Screen 然后告诉老人怎么找到/使用某些功能





需求：老年人不会使用手机的一些功能app会查看 手机 桌面的 share Screen 然后告诉老人怎么找到/使用某些功能



界面：



1. 第一次打开app 登陆账号 apple 账号， 走一个纯语音+interactive design来设置子女的性格/声音
2. 主界面参考截图 包含右上角有一个 设置按钮，下面有麦克风开关，屏幕共享开关
3. 设置页面





功能： 复制子女的说话声音，性格，和习惯等。 

技术栈： 

​	1. 复制声音用 Myshell 的 开源项目 OpenVoice（也可以用别的，如果更好） （难点： python项目如何结合到iOS app （Swift+ Swift UI)

		2. AI 功能的会调用外部API （包括OpenAI, Claude, Deepseek, etc.)
		2. 前端和后端全部在用户手机运行大部分服务在 api端执行， open voice需要本地
		2. Swift UI + Swift + CoreDate



项目哲学：
 Keep it simple, but UI needs to be very smooth and aesthetic . 

