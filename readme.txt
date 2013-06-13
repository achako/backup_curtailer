BackupCurtailer Readme

Esxi5.1にバックアップされているバックアップファイルを間引きます。
バックアップファイルの合計サイズが指定サイズを超えると半分に間引きます。

対応バージョン　Esxi5.1


○設定方法
	バックアップファイルが溜め込まれているEsxiにbackup_curtailerフォルダ以下をコピーする
	設定ファイルを設定する(設定パラメータの説明は「設定ファイル」参照)
	ファイアーウォールをsmtpポートを開くように設定する(「ファイアーウォールでsmtpポートを開く」参照)
	cronで定期実行設定( 「定期実行の設定」参照 )


○設定ファイル(backup_curtailer.conf)
	BACKUP_DIR				バックアップを保存しているディレクトリ
	BACKUP_DELETE_SIZE		半分に間引く処理を行うサイズ(MByte単位)
	BACKUP_PREFIX			バックアップファイルのプレフィックス

	BACKUP_LOG_DIR			バックアップログの保存先ディレクトリ
	BACKUP_LOG_CNT			バックアップログの保存数(保存数を超えると古いものから削除される)

	USE_EMAIL				このスクリプトが走るたびにEメールを送信するかどうか( 1:送信する, 0:送信しない )
	EMAIL_SERVER			smtpサーバー
	EMAIL_PORT				smtpポート
	EMAIL_TO				送信先アドレス
	EMAIL_FROM				送信者アドレス


○ファイアーウォールでsmtpポートを開く
	メールを送るときにはファイアーウォールの設定を変更してsmtpのポートをあける必要があります。
	ghettoVCB等でバックアップステータス等をメールで送信しようとすると、デフォルトのままだとファイアーウォールに阻まれて送信失敗します。
	なので、ファイアーウォールの設定を変更してやる必要が出てきます。

	設定方法
	/etc/vmware/firewall/service.xmlを任意の場所にコピー
	ここではsmtp送信用ポート25番を開く設定で、
	/vmfs/volumes/datastore1/ghettoVCB内にコピー
		cp /etc/vmware/firewall/service.xml /vmfs/volumes/datastore1/ghettoVCB/
		以下をファイル内に追加する
		vi /vmfs/volumes/datastore1/ghettoVCB/service.xml
	 
		(</ConfigRoot>の一つ上)
		<service id="0033">
			<id>smtp</id>
			<rule id='0000'>
				<derection>outbound</derection>
				<protocol>tcp</protocol>
				<porttype>dst</porttype>
				<port>25</port>
			</rule>
			<enabled>true</enabled>
			<required>false</required>
		</service>

	コピー元にコピーする
		cp /etc/vmware/firewall/service.xml /vmfs/volumes/datastore1/ghettoVCB/service.xml
	 
	/etc/profile.localを編集
	このままでは再起動したときに設定が元通りになってしまうので、再起動時の対策をしておく
		vi /etc/profile.local
		以下の3行を追加する
			rm /etc/vmware/firewall/service.xml
			cp -p /vmfs/volumes/datastore1/ghettoVCB/service.xml /etc/vmware/firewall/service.xml
			esxcli network firewall refresh
	         「/vmfs/volumes/datastore1/ghettoVCB/service.xml」の部分は先程service.xmlを作成した場所を指定

	ネットワークのファイアーウォールルールを再設定
		esxcli network firewall refresh
	 
	ポートが開いているか確認
		nc smtp.artdink.co.jp
		このコマンドを打って、下に色々文字が出てきたら成功
		ctrl + cを押して戻る
		何事もなかったようにコマンド入力に戻ったら失敗

		
○定期実行の設定
	Esxiサーバーのファイルを以下の手順で編集・設定します。
	
	クーロンジョブの設定ファイルを編集する
		vi /var/spool/cron/crontabs/root

	以下の赤字部分を編集
		min	hour	day	mon	dow		command
		 0	 7		*	*	1-7	 	/vmfs/volumes/datastore1/backup_curtailer/backup_curtailer.sh
	
	crondを再起動する
		kill $(cat /var/run/crond.pid)
		/usr/lib/vmware/busybox/bin/busybox　crond
	
	再起動を行ったときに設定が消えるので、別のファイルに再起動したときに設定しなおすようにしています。そのファイルを編集ます。
		vi /etc/rc.local.d/local.sh
		以下の数値と*の部分を↑で設定したのと同じ値に編集
		 #! /bin/ash
		・・・

		/bin/kill $(cat /var/run/crond.pid)
		/bin/echo "0 7 * * 1-7 /vmfs/volumes/datastore1/backup_curtailer/backup_curtailer.sh" >> /var/spool/cron/crontabs/root
		/usr/lib/vmware/busybox/bin/busybox　crond


