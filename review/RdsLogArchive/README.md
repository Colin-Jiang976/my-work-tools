# RdsLogArchive — 下载后日志归档

Windows PowerShell 5.1本地工具。先由人从AWS取得日志，本工具处理明确选中的四个文件。它不访问AWS，也不根据关键词确认业务正常。

## 使用

先运行`Run-Demo.cmd`看虚构材料预览；`Run-Demo.ps1 -Apply`会在独立demo-runs目录实际复制四文件。

真实作业复用前，复制config.example.json为config.json，填写InputDirectory、ArchiveRoot和Files；Files的前两项归Group1，后两项归Group2。顺序由操作者明确指定，不从修改时间猜测。相对路径相对于配置文件所在目录解释。

实际手顺是主DB下载A、B，接着备用DB下载同名A、B；Group1对应主DB，Group2对应备用DB。示例用query-a.log、query-b.log、query-a (1).log、query-b (1).log模拟四个落盘名字，后两项归档后也恢复A/B，因组目录不同不会相互覆盖。` (1)`仅为虚构重复命名示例，须按实际落盘文件名配置，不能据后缀或内容自动判断来自哪个DB；Downloads已有旧文件时后缀也可能不同。

```powershell
.\Start-Archive.ps1 -ConfigPath .\config.json
.\Start-Archive.ps1 -ConfigPath .\config.json -Apply
```

第一条只预览，不创建归档、不打开文件；第二条复制到ArchiveRoot/当天日期/Group1及Group2，输出archive-report.json。源文件保留、字节不转换，复制后用SHA256核对。日期目录存在就停止；同一天另存一批时选择另一个明确的ArchiveRoot，不改假日期或覆盖旧档。

Encoding用于读取关键词，演示为UTF8；可明确设成Windows PowerShell支持的Default等编码，真实日志编码仍需本人核实。关键词计数表示匹配行数，不能解释成事故数量或健康结论。默认不打印日志原文。只有同时给`-Apply -OpenMatchedFiles`才打开命中的归档副本。

符合原工作手顺的实际运行方式为`Start-Archive.ps1 -ConfigPath .\config.json -Apply -OpenMatchedFiles`：自动搜索四份日志，只打开命中项，再由人读报错、判断是否需要处理。虚构演示继续不打开应用，不需要为更新示例再跑一遍。

BackupRoot默认null。需要备份时明确填写独立目标，并加`-Apply -Backup`；本地输出和备份都拒绝覆盖。网络共享是否可达取决于实际环境，本轮只验证本地备份替身。备份失败会返回非零退出码，保留本地归档。中途复制失败的.staging目录留待人工查看，不冒充完成目录。

## 本轮变化

用中性名称、Group1/Group2代替原业务项目名及可能误导来源的分组名；配置中不带真实本地/公司共享路径。不加自动下载、解压、日志业务判错或自动清理下载目录。源文件选择从“最近20分钟自动选4个”改为显式列出4个，因此真实操作便利性需本人结合文件命名习惯核对；尚未替换工作版本。

测试：`Test-Archive.ps1`，只使用本目录下生成的虚构测试文件。详情见上级VALIDATION.md。

实现参考：[复制且拒绝覆盖](https://learn.microsoft.com/en-us/dotnet/api/system.io.file.copy?view=netframework-4.8.1)、[SHA256校验](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/get-filehash?view=powershell-5.1)、[按字面文件名查找文本](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/select-string?view=powershell-5.1)。
