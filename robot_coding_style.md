# Robot Framework Coding Style

| 版本 | 更新日期 | 維護者 |
|------|----------|--------|
| V1.1.0 | 2026-08-19 | Jet Qian |

**適用範圍**:本專案**所有 Robot Framework 相關程式碼** —— `.robot` / `.resource` 測試與資源檔,以及供 RF 呼叫的 Python custom library(例如 `lib/**`)。**非 Viper 限定**。

本檔是撰碼規範的**唯一來源(source of truth)**。每條規則經確認後逐條加入,並在需要時附上「原因 / 範例」。

---

## 1. Python Custom Library(`lib/**`)

### 1.1 Logging(log 輸出)

#### R1 — public keyword 的 log 表頭

每個**可被外部呼叫的 keyword**(public;`_` 開頭的私有 method 不加)開頭固定放這三行:

```python
arg_info = f"參數1={參數1}, 參數2={參數2}"
logger.write(f"[Arguments]: {arg_info}", 'INFO')
logger.console(f"\n\t<LIB_NAME> - <KW_Name> : {arg_info}")
```

規則:
1. **只有 public keyword 要加**;`_` 開頭的私有 method 不加。
2. **`arg_info`**:把 keyword 的**所有參數**以 `名稱={值}` 逐一列出(`self` 不算)。
   - `*arg`(可變數量參數)以 `arg={arg}` 呈現(印整個 tuple)。
3. 三行**全部用 f-string**(依循 R-default),不用 `.format()`。
4. **`<LIB_NAME>`** = library(class)全名,大小寫照舊(例:`TeraViperUART`、`TeraViperCM`)。
5. **`<KW_Name>`** = 方法全名,底線換空格,**每個被切開的段落首字母大寫(嚴格 Title Case,縮寫也正規化)**。
   - 例:`run_ttl` → `Run Ttl`、`ccli_send` → `Ccli Send`、`cli_send` → `Cli Send`、`bcli_send_and_return` → `Bcli Send And Return`。

範例:
```python
def bcli_send(self, cmd_string, prompt=None, log_name=None):
    arg_info = f"cmd_string={cmd_string}, prompt={prompt}, log_name={log_name}"
    logger.write(f"[Arguments]: {arg_info}", 'INFO')
    logger.console(f"\n\tTeraViperUART - Bcli Send : {arg_info}")
    ...
```

### 1.2 Docstring
<!-- 規則逐條加入於此 -->

### 1.3 一般撰碼

#### R-default(字串格式化)

字串一律**優先用 f-string**。凡是能用 f-string 表示的(行內字面值)都要用;唯有無法用 f-string 表示者才保留 `.format()`,例如:

- 模板先存成變數再套用:`t = "..."; t.format(x)`
- 以序列展開帶入:`"...".format(*args)`

範例:
```python
# Bad
logger.write("Run {} => {}".format(ttl, judge_content), 'INFO')
# Good
logger.write(f"Run {ttl} => {judge_content}", 'INFO')
```

#### R-none(與 None 比較)

與 `None` 比較一律用 **`is None` / `is not None`**(None 是單例,用 identity 比較),不用 `== None` / `!= None`。

```python
# Bad
if log_name != None:
# Good
if log_name is not None:
```

## 2. Robot / Resource(`.robot` / `.resource`)

### 2.1 Keyword 命名

#### R2 — resource file 的 keyword 綁定檔名

`.resource` 檔裡**給外部呼叫**的 keyword,名稱一律綁定檔名:

```
<主檔名全大寫,底線換空格> - <有意義的 keyword 名稱>
```

規則:
1. 取主檔名(不含 `.resource`),**整串轉大寫**,底線 `_` 換成一個**空格**。
2. 接 ` - `(前後各一個空格)。
3. 之後才是這個 keyword 的有意義命名。
4. 有意義的那段**沿用自然大小寫、縮寫照舊**(`CCLI Login`、`Check Current FW Version`、`Resolve DUT eAMP IPv6`)。這裡**不套 R1 的嚴格 Title Case** —— R1 只管 Python custom library 的 log 表頭。
5. **只在該 resource 內部使用**的 keyword 不套這條規則,改以 `_` 開頭表示內部用。

範例:

| 檔名 | 前綴 | keyword 全名 |
|------|------|--------------|
| `IT_Common.resource` | `IT COMMON` | `IT COMMON - Run Dut Command And Return` |
| `IT_Common.resource` | `IT COMMON` | `IT COMMON - Wait For Dut Cli Field` |

內部用 keyword:

```robotframework
# IT_Common.resource 內,只被同檔的 IT COMMON - Wait For Dut Cli Field 呼叫
_Get Cli Field
    [Arguments]    ${output}    ${field}
    ...
```

原因:log.html 上看到 keyword 名稱就知道它出自哪支 resource、走的是哪個介面;`_` 開頭則一眼看出「這不是給外面呼叫的」。

### 2.2 檔案與資料夾結構

#### R3 — 測項的資料夾結構

放 robot 測項的結構固定為「一個測項一個資料夾,資料夾內的 `.robot` 檔名 = `#` + 資料夾名」:

```
<Test_folder_root>
    - test_name1
        - #test_name1.robot
    - test_name2
        - #test_name2.robot
```

第二階資料夾**可以加數字前綴**來決定 robot 的執行順序,**但 `.robot` 檔名不跟著改**:

```
<Test_folder_root>
    - 0_test_name2
        - #test_name2.robot
    - 1_test_name1
        - #test_name1.robot
```

上面會讓 robot 先跑 `0_test_name2` 再跑 `1_test_name1`。

檔名不跟著加前綴的原因:各 suite 慣用的

```robotframework
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
```

是靠 `#` 把資料夾前綴切掉的,所以 `.robot` 檔名保持不變,`${case_name}` 與 log 落點目錄就不會被排序用的數字污染。

### 2.3 Test case 內容

#### R4 — log 檔名在 case 開頭集中宣告

每個 test case 的**第一段**,用 `VAR` 把這個測項可能產生的**所有** log 檔名宣告出來;後續步驟一律引用變數,不在 keyword 呼叫處寫字面值。

```robotframework
[test1]Get CM IP
    VAR    ${cos_log}    ${case_name}-1_cos.log
    COS.Connect    ssh_setting=${SSH_CABLEOS}    main_log_name=${cos_log}
```

命名慣例:

| 項目 | 格式 | 範例 |
|------|------|------|
| 變數名 | `${<用途>_log}` | `${cos_log}` / `${uart_log}` / `${cos_snr_log}` |
| 檔名 | `${case_name}-<case 序號>_<用途>.log` | `${case_name}-1_cos.log` |

`${case_name}` 來自各 suite 慣用的 `${SUITE NAME.rsplit('#')[-1]}`(見 R3),所以檔名自帶測項名,不同 suite 的 log 不會撞名。

原因:測項會產出哪些檔案是讀 case 時最先想知道的事,集中在開頭就不必逐行找 `log_name=`;同一個檔名被多個步驟共用時,也不會改一處漏一處。

### 2.4 變數

#### R5 — 變數的建立與指派一律用 `VAR`

`.robot` / `.resource` 裡要建立或改寫變數時,一律用 RF 7.0 起的 `VAR` 語法,scope 用 `scope=` 指定:

```robotframework
VAR    ${log_name}    ${case_name}-1_gnmi.log
VAR    ${BASELINE}    ${value}    scope=SUITE
VAR    ${DUT_EAMP_IPV6}    ${eamp_v6}    scope=GLOBAL
```

不要用 `Set Variable`、`Set Test Variable`、`Set Suite Variable`、`Set Global Variable`。

`scope` 可用值:`LOCAL`(預設)/ `TEST` / `TASK` / `SUITE` / `SUITES` / `GLOBAL`。`SUITES` 等同舊寫法的 `children=True`。變數名稱可以是巢狀的(`VAR    ${${var_name}}    ${result}    scope=SUITE`)。

**兩種情況不受這條規範:**

1. **從 keyword 回傳值指派** —— 這本來就不是 `Set Variable` 家族,維持原樣:

```robotframework
${rslt}=    GNMI.Get And Return    /ds-profile
${result}=    Catenate    SEPARATOR=:    ${result}    ${pair}
```

2. **就地修改既有物件** —— `Set To Dictionary`、`Append To List` 這類是 Collections 的操作,`VAR` 取代不了:

```robotframework
Set To Dictionary    ${SSH_DUT_EAMP}    host=${eamp_v6}
```

原因:RF 官方在 `BuiltIn.py` 的 docstring 裡已把 `Set Variable` 標為 "considered deprecated",其餘 `Set * Variable` 標為 "the `VAR` syntax ... is recommended over this keyword"。

另一個實際好處是 **IDE 認得 `VAR` 是變數宣告** —— `Set Suite Variable` 建立的變數只在執行期存在,靜態分析看不到,後續引用會被畫上 undefined variable 的紅線。

### 2.5 檔頭

#### R6 — 檔頭與版號

**每個** RF 檔(`.robot` / `.resource` / 變數檔)開頭固定放這個註解區塊,欄位順序不變:

```robotframework
*** Settings ***
# @author: Jet Qian
# @version: V1.0.0
# @updated: 2026-08-19
# @comment: 一句話說明這個檔案是什麼
```

變數檔沒有 `*** Settings ***`,檔頭改放在**檔案最上方、`*** Variables ***` 之前**(RF 允許第一個 section 之前有註解行)。

**`@version` 只加在會被別人匯入的檔案上:**

| 檔案 | 誰依賴它 | `@version` |
|------|----------|-----------|
| `.resource` | 被 `Resource` 匯入 | **要** |
| `variables/sample/*.robot` | 參數名稱契約,各人真值檔由它衍生 | **要** |
| `__init_resource.robot` | 被該資料夾下每支 suite 匯入 | **要** |
| 測項(`#<資料夾名>.robot`) | 不被任何東西匯入 | **不要** |

原因:版號是**被別人依賴的契約的世代編號**。測項是終端消費者,沒有 consumer 就沒有對象可以宣告世代,所以它只留 `@author` / `@updated` / `@comment` —— 那是 provenance,不是契約。同理,Python custom library 的版號寫在 `__version__`(見 1.x),不寫在檔頭。

**`@updated`** 是**這次實質改動的日期**,與 lib `__date__` 同義。升版一定會一起動;只改註解時只動 `@updated`、不升版。**這個欄位只有一個意思**,不因檔案有沒有版號而改變解讀。

**升版規則**(沿用 lib 的慣例):

| 情況 | 動作 |
|------|------|
| 對外形狀不變(內部實作、log 訊息、值的調整) | 第三碼 +1 |
| **破壞性變更** | 第二碼 +1 |
| 只改註解 | 不升版,只動 `@updated` |

「破壞性」各檔類分別定義:

- **`.resource`**:keyword 改名 / 刪除 / 參數簽章改變。
- **`variables/sample`**:參數**改名或移除**。**新增**參數不算破壞性(別人的真值檔缺了新參數會壞,但那是 R-未定的另一件事,依現況走第三碼)。

**版號在 commit 時才決定**,開發過程中不要順手加 —— 版號代表對外發布的節奏,不是編輯次數的計數器。

兩個導入期的例外,寫下來免得被當成錯誤:

1. **導入這條規則時所有檔案從 V1.0.0 起算,`@updated` 保持原值**。加一行 `@version` 是註解改動,契約並沒有在那天變。
2. **真值檔(`variables/*.robot`)的檔頭不要求維護**。它是從 `variables/sample/` 複製來的,會連檔頭一起帶過去;那個停住不動的版號正好是「我是從哪一版複製的」的痕跡,跟範本 `diff` 一下就知道自己落後幾代。
