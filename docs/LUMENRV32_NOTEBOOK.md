# LumenRV32 闈㈣瘯澶嶄範绗旇

> 鐩爣锛氳鍏峰鏁板瓧鐢佃矾鍩虹鐨勮鑰咃紝鍦ㄧ悊瑙ｆ湰绗旇鍜屽搴?RTL 鍚庯紝鑳芥竻妤氳鏄庨」鐩殑璁捐杈圭晫銆佸叧閿彇鑸嶃€侀獙璇佽瘉鎹笌宸茬煡闄愬埗銆?>
> 閫傜敤杈圭晫锛歚RV32IM` 鍗曞彂灏勪簲绾ф祦姘?CPU銆両/D Cache銆乶ative-to-AXI4 memory path銆丳MU銆乑U15EG USER2 JTAG/DMI銆傚畠涓嶆槸瀹屾暣涔卞簭 CPU銆佸畬鏁?RISC-V Debug Spec 瀹炵幇锛屼篃涓嶆槸宸插畬鎴?CDC/LEC sign-off 鐨勮姱鐗囬」鐩€?
## 瀵艰埅鐩綍

### Part I锛欳PU 鏍镐笌寰灦鏋?
- [0. 椤圭洰瀹氫綅銆佽竟鐣屽拰鎴愭灉](#0-lumenrv32-cpu)
- [1. CPU 鏍?RTL 鏂囦欢鍦板浘](#1-缁撴瀯杈圭晫涓庢枃浠跺湴鍥?
- [2. 浜旂骇娴佹按锛欼F/ID/EX/MEM/WB](#2-浜旂骇娴佹按涓嶆槸浜斾釜-cpu鑰屾槸浜旀潯鎸囦护閲嶅彔鎵ц)
- [3. RV32IM 鎸囦护銆丆SR銆丆LINT 涓庤蒋浠舵墽琛岃繃绋媇(#3-鎸囦护杞欢绌剁珶璁╃‖浠跺仛浠€涔?
- [4. Register銆丆ache銆丷AM/DDR](#4-registercacheramddr瀹归噺瓒婂ぇ绂?alu-瓒婅繙)
- [5. Fetch銆両-Cache銆乥urst 涓?FENCE.I](#5-fetchi-cacheburst-鍜?fencei)
- [6. Hazard锛歠orwarding銆乴oad-use銆乺edirect/flush](#6-hazardipc-涓轰粈涔堜笉鎬绘槸-1)
- [7. Frontend锛欱TB銆?-bit BHT 涓?prefetch queue](#7-frontendbtbbht-涓?prefetch-queue)
- [8. D-Cache 涓?2-entry store queue](#8-d-cache-涓?2-entry-store-queue)

### Part II锛氬澶栨帴鍙ｄ笌鍗忚杞崲

- [9. Native memory銆丄XI 涓?UVM DUT 杈圭晫](#9-native-memoryaxi-涓?uvm-鍒板簳楠岃瘉浠€涔?
- [9.1 瀹為檯鍗忚杞崲涓庢椂閽熻竟鐣宂(#91-鏈」鐩疄闄呯殑鍗忚杞崲涓庢椂閽熻竟鐣?
- [17. AXI4 crossbar 涓?AXI4-Lite/APB control island](#17-axi4-crossbar-涓?control-plane-杈圭晫)

### Part III锛氬璁俱€丏MA 涓庢€ц兘瑙傛祴

- [18. APB peripheral subsystem銆丏MA銆丆SR/CLINT 涓?PMU](#18-pmu浠庤鏁板櫒鍒版€ц兘鍒ゆ柇)

### Part IV锛欳DC 涓?USER2 JTAG/DMI debug

- [10. CDC 缁撴瀯閫夋嫨涓?reset synchronization](#10-cdc涓嶅悓璺ㄥ煙鍦烘櫙瑕佺敤涓嶅悓宸ュ叿)
- [11. ZU15EG USER2 JTAG/DMI debug](#11-user2-jtagdmi浠庣數鑴戝埌-cpu-halt-鐨勯摼璺?

### Part V锛欼mplementation 涓?PPA

- [12. DC銆丼TA 涓?EX-to-JALR timing case study](#12-鏃跺簭dcsta-涓?ex-to-jalr-浼樺寲鏁呬簨)
- [13. ZU15EG FPGA 缁撴灉銆丆oreMark銆丳PA 涓庨檺鍒禲(#13-fpga-缁撴灉ppa-鍜岃瘹瀹炶竟鐣?
- [22. 闈㈣瘯鏃跺浣曡〃杩?PPA 璇佹嵁](#22-闈㈣瘯鏃跺浣曡〃杩?ppa-璇佹嵁)

### Part VI锛歏erification

- [19. Directed UVM foundation](#19-directed-uvm-foundation)
- [20. 楠岃瘉鐘舵€併€乧overage 涓?static-check 杈圭晫](#20-楠岃瘉鐘舵€佽鐩栦笌鍥炲綊杈圭晫)
- [21. 娉㈠舰闃呰锛歯ormal銆乥ubble銆乻tall銆乫lush](#21-娉㈠舰闃呰normalbubblestallflush)

### Part VII锛氶潰璇曚笌瀹炴垬閲嶇偣

- [14. 瀹為檯杩愯涓庢尝褰㈠涔犱换鍔(#14-瀹為檯杩愯涓庢尝褰㈠涔犱换鍔?
- [15. 闈㈣瘯甯搁棶闂](#15-闈㈣瘯甯搁棶闂绠€娲佷笖鍑嗙‘鐨勫洖绛?
- [16. 鍗佸垎閽?/ 涓€灏忔椂 / 娣卞叆澶嶄範璺嚎](#16-涓変釜澶嶄範闃舵)
- [23. 闈㈣瘯琛ㄨ揪妯℃澘涓庡凡鐭ラ檺鍒禲(#23-闈㈣瘯琛ㄨ揪妯℃澘涓庡凡鐭ラ檺鍒?
- [24. 杩介棶娓呭崟銆佽瘉鎹笌涓嶈兘澶稿ぇ鐨勮〃杩癩(#24-杩介棶娓呭崟璇佹嵁涓庝笉鑳藉じ澶х殑琛ㄨ堪)

## 0. LumenRV32 CPU

LumenRV32 鏄竴棰?**RV32IM銆佸崟鍙戝皠銆侀『搴忔墽琛屻€佷簲绾ф祦姘?* 鐨?CPU銆傛瘡鎷嶆渶澶氳繘鍏ヤ竴鏉℃柊鎸囦护锛涗笉鍚屾寚浠ゅ悓鏃跺垎鍒鍦?IF/ID/EX/MEM/WB 浜斾釜闃舵锛屽洜姝ょ悊鎯虫儏鍐垫帴杩?IPC=1锛岃€屼笉鏄竴鎷嶅仛瀹屼竴鏉℃寚浠ゃ€傚綋鍓嶅彲澶嶇幇鐨?CoreMark 璁℃暟绐楀彛缁欏嚭绾?`0.705 IPC`锛涘畠鏄€ц兘璇婃柇璇佹嵁锛屼笉搴旇璇涓虹悊璁哄嘲鍊笺€?
瀹冪殑涓绘暟鎹矾寰勬槸锛?
```text
CPU pipeline
  鈹溾攢 IF 鈫?prefetch queue 鈫?I-Cache 鈫?native instruction port
  鈹斺攢 MEM 鈫?D-Cache + 2-entry store queue 鈫?native data port
                 鈫?           native-to-AXI4 adapters 鈫?AXI4 fabric 鈫?BRAM/RAM/DDR 鎴栧璁?```

闈㈣瘯涓渶鍊煎緱璁茬殑涓夋闂幆锛?
1. **寰灦鏋?*锛歠orwarding銆乴oad-use interlock銆乥ranch redirect/flush銆両/D Cache銆丅TB/2-bit BHT銆?2. **鍙獙璇佹€?*锛氬湪 CPU native-memory 杈圭晫寤虹珛 SystemVerilog UVM foundation锛涘凡璺戝畾鍚?smoke 鍜?pipeline-hazard 娴嬭瘯锛屽寘鍚?monitor銆乻coreboard銆乧overage銆丼VA 鍜屽洖褰掑叆鍙ｃ€?3. **宸ョ▼璇佹嵁**锛歓U15EG 鐨?USER2 JTAG/DMI 閫氳繃鏉胯浇 USB-JTAG 鎵撻€?`DMSTATUS 鈫?halt 鈫?GPR read 鈫?resume`锛涘啀鐢?DC timing report 椹卞姩 EX-to-JALR 鐨勫眬閮ㄦ椂搴忛噸鏋勩€?
涓€鍙ヨ瘽鐗堟湰锛?
> 鎴戝疄鐜板苟楠岃瘉浜嗕竴棰楀彲缁煎悎鐨勪簲绾?RV32IM CPU锛涘皢 cache/microarchitecture 涓?AXI 鍗忚閫傞厤瑙ｈ€︼紱鍦?FPGA 涓婂畬鎴?USER2 DMI 璋冭瘯闂幆锛屽苟鐢?pre-layout DC timing cone 瀹氫綅鍜岄噸鏋勪簡 JALR 渚濊禆鍏抽敭璺緞銆?
## 1. 缁撴瀯杈圭晫涓庢枃浠跺湴鍥?
| 灞傛 | 涓昏 RTL | 浣犺鑳藉洖绛旂殑闂 |
|---|---|---|
| Pipeline | `rtl/core/riscv_cpu_core.v`銆乣ifetch.v`銆乣id.v`銆乣ex.v`銆乣mem.v` | 涓€鏉℃寚浠ゅ浣曟祦缁忎簲绾э紵hazard 濡備綍澶勭悊锛?|
| 娴佹按瀵勫瓨鍣?鐘舵€?| `if_id.v`銆乣id_ex.v`銆乣ex_mem.v`銆乣mem_wb.v`銆乣pc_reg.v` | flush銆乭old銆亀riteback 鍒嗗埆鏀瑰彉浠€涔堬紵 |
| Register file/鎺у埗 | `regs.v`銆乣ctrl.v`銆乣csr_reg.v`銆乣clint.v` | x0 涓轰粈涔堟亽涓?0锛焛nterlock 鍦ㄥ摢閲屼骇鐢燂紵 |
| Memory hierarchy | `icache.v`銆乣dcache.v`銆乣cache_ram_1r1w.v` | miss 鎬庝箞濉?line锛焥tore 涓轰綍鏈?queue锛?|
| Frontend | `branch_predictor.v`銆乣ifetch.v` | BTB/BHT 棰勬祴浠€涔堬紵閿欎簡濡備綍鎭㈠锛?|
| AXI integration | `rtl/interconnect/native_to_axi4_master.v`銆乣axi4_crossbar.v` | 涓轰粈涔?core 涓嶇洿鎺ュ啓 AXI锛熸湰椤圭洰 AXI 鐨勮竟鐣岋紵 |
| Debug | `rtl/debug/jtag_user2_dmi_transport.v`銆乣jtag_dm.v`銆乣jtag_bscan2_user2.v` | USER2銆丏MI銆丆DC 鍜屾澘娴嬮棴鐜槸浠€涔堬紵 |
| Verification | `verify/uvm_cpu/` | UVM 鐨?DUT 杈圭晫銆乻coreboard銆佽鐩栬寖鍥达紵 |

## 2. 浜旂骇娴佹按锛氫笉鏄簲涓?CPU锛岃€屾槸浜旀潯鎸囦护閲嶅彔鎵ц

### 2.1 浜旂骇鍚箟

| 闃舵 | 鍋氫粈涔?| 涓昏浜х墿 |
|---|---|---|
| IF (Instruction Fetch) | 鐢?PC 鍙栨寚銆佺敤棰勬祴鍣ㄧ粰涓嬩竴 PC | instruction銆丳C銆乸redicted next PC |
| ID (Instruction Decode) | 璇戠爜銆佽瀵勫瓨鍣ㄣ€佹娴?dependency | opcode 鎺у埗淇″彿銆乣rs1/rs2` 鏁版嵁銆佺珛鍗虫暟 |
| EX (Execute) | ALU銆佹瘮杈?branch銆佽绠?load/store 鍦板潃 | ALU result銆乥ranch taken/target銆乪ffective address |
| MEM (Memory) | D-Cache 鏌ユ壘銆乴oad/store 涓庡悗绔彙鎵?| load data 鎴?store 璇锋眰瀹屾垚 |
| WB (Write Back) | 灏嗚绠楃粨鏋滄垨 load 鏁版嵁鍐欏叆 GPR | `rd`銆亀rite data銆乺eg_write |

渚嬪瓙锛?
```asm
addi x1, x0, 5
addi x2, x1, 7
add  x3, x1, x2
```

绋冲畾鍚庡彲浠ュ悓鏃跺彂鐢燂細`addi x1` 鍦?WB銆乣addi x2` 鍦?MEM銆乣add x3` 鍦?EX銆佷笅涓€鏉″湪 ID銆佸啀涓嬩竴鏉″湪 IF銆傚畠浠叡鐢ㄧ‖浠讹紝浣嗛€氳繃娴佹按瀵勫瓨鍣ㄤ繚瀛樺悇鑷殑 PC銆佸瘎瀛樺櫒鍙枫€佹暟鎹拰鎺у埗淇″彿銆?
### 2.2 MEM 鍜?WB 鐨勫尯鍒?
- **MEM** 鏄€滆闂暟鎹瓨鍌ㄥ眰绾р€濈殑闃舵銆俙lw x5, 12(x1)` 鍦?EX 寰楀埌鍦板潃锛屽湪 MEM 鐢ㄨ鍦板潃鏌?D-Cache锛沨it 鍒欏緱鍒版暟鎹紝miss 鍒欏彂鍑?line-fill 璇锋眰骞剁瓑寰呫€?- **WB** 鏄€滄洿鏂版灦鏋勫瘎瀛樺櫒鐘舵€佲€濈殑闃舵銆傚 `lw`锛學B 鎶?MEM 杩斿洖鐨勬暟鎹啓缁?`x5`锛涘 `add`锛學B 鎶?ALU 缁撴灉鍐欑粰 `rd`锛沗sw`銆乣beq` 閫氬父涓嶅啓 GPR锛屽洜姝ょ粡杩?WB 鏃?`reg_we=0`銆?
娉ㄦ剰锛氫竴鏉℃湁鏁?`beq` 缁忚繃 MEM/WB 浣嗘病鏈夊啓瀵勫瓨鍣ㄦ垨鍐呭瓨锛?*涓嶆槸 bubble**銆傚畠鐨勬暟鎹?鎺у埗浠嶉殢娴佹按瀵勫瓨鍣ㄦ祦鍔紝鍙槸鍓綔鐢ㄦ帶鍒跺叏涓?0銆傜湡姝?bubble 鏄‖浠舵敞鍏ョ殑 NOP锛泂tall/hold 鍒欐槸鏌愪簺娴佹按瀵勫瓨鍣ㄤ繚鎸佸墠涓€鎷嶅€间笉鏇存柊銆?
## 3. 鎸囦护锛氳蒋浠剁┒绔熻纭欢鍋氫粈涔?
### 3.1 甯歌 RV32IM 鎸囦护

| 绫诲埆 | 绀轰緥 | 璇箟 |
|---|---|---|
| 绠楁湳 | `add x3,x1,x2` | `x3 = x1 + x2` |
| 绔嬪嵆鏁?| `addi x1,x0,5` | `x1 = 0 + 5` |
| 閫昏緫/绉讳綅 | `and/or/xor/sll/srl/sra` | 浣嶈繍绠楁垨绉讳綅 |
| 姣旇緝 | `slt/sltu` | 姣旇緝缁撴灉鍐?0/1 |
| load | `lw x5,12(x1)` | `x5 = Memory[x1 + 12]` |
| store | `sw x5,12(x1)` | `Memory[x1 + 12] = x5` |
| 鏉′欢鍒嗘敮 | `beq x1,x2,target` | 鐩哥瓑鍒?PC 璺冲埌 target锛屽惁鍒欓『搴忔墽琛?|
| 璺宠浆 | `jal rd,target` | 璺宠浆锛屽悓鏃舵妸杩斿洖 PC 鍐?`rd` |
| 闂存帴璺宠浆 | `jalr rd,imm(rs1)` | 璺冲埌瀵勫瓨鍣ㄨ绠楀嚭鐨勫湴鍧€锛涘父鐢ㄤ簬 return/鍑芥暟鎸囬拡 |
| 涔橀櫎娉?| `mul/div/rem` | RV32M 鎵╁睍鐨勪箻銆侀櫎銆佷綑鏁?|
| CSR | `csrrw/csrrs/csrrc` | 璇绘敼鍐欐帶鍒?鐘舵€佸瘎瀛樺櫒 |
| FENCE.I | `fence.i` | 璁╂鍓嶅浠ｇ爜鍖虹殑鍐欏叆瀵逛箣鍚庡彇鎸囧彲瑙?|

杞欢宸ョ▼甯?缂栬瘧鍣ㄦ妸 C 绋嬪簭缈昏瘧鎴愪笂杩颁簩杩涘埗鎸囦护锛岄摼鎺ュ櫒鎶婂畠浠斁杩?ROM/DDR 鐨勫湴鍧€绌洪棿銆傜‖浠跺苟涓嶇悊瑙?C锛涘畠鍙湪姣忔媿鎸?ISA 璇戠爜骞舵墽琛屾寚浠ゃ€傝蒋浠跺喅瀹氣€滃仛浠€涔堛€佹暟鎹斁鍦ㄥ摢閲屸€濓紝CPU 纭欢鍐冲畾鈥滃浣曟寜鏃跺簭鎵ц銆佷綍鏃跺懡涓?cache銆佷綍鏃?stall鈥濄€?
### 3.2 `lw` 鍜?`sw` 閫愭渚嬪瓙

鍋囪 `x1=0x8000_1000`锛?
```asm
lw x5, 12(x1)      # 璇诲湴鍧€ 0x8000_100C 鐨?32-bit 鏁版嵁缁?x5
sw x5, 16(x1)      # 灏?x5 鐨?32-bit 鏁版嵁鍐欏埌 0x8000_1010
```

`lw`锛欵X 绠?`0x8000_100C` 鈫?MEM 鏌?D-Cache 鈫?WB 鍐?`x5`銆?
`sw`锛欵X 绠楀湴鍧€骞舵惡甯﹀啓鏁版嵁/byte mask 鈫?MEM 鏇存柊 D-Cache锛屽苟鎶?write-through 宸ヤ綔浜ょ粰 store queue 鎴栧悗绔€?
### 3.3 RV32M锛氫箻娉曘€侀櫎娉曚笌瀹炵幇鍙栬垗

`RV32M` 瑙勫畾鐨勬槸 `mul/div/rem` 绛夋寚浠ょ殑**鏋舵瀯缁撴灉**锛屽苟涓嶈瀹氬唴閮ㄥ繀椤讳娇鐢ㄥ摢涓€绉嶄箻闄ゆ硶鍣ㄣ€傚綋鍓嶅疄鐜扮殑鍙栬垗鏄細

| 鎿嶄綔 | 涓昏瀹炵幇浣嶇疆 | 褰撳墠瀹炵幇鏂瑰紡 | 璁捐鍙栬垗 |
|---|---|---|---|
| `mul/mulh/mulhu/mulhsu` | `rtl/core/ex.v` | EX 缁勫悎 `32脳32 鈫?64-bit` 涔樻硶锛屾寜鎸囦护閫夋嫨楂?浣?32 bit | 鍚炲悙濂姐€佷唬鐮佺洿鎺ワ紱鍙兘澧炲姞 EX 寤惰繜鍜岄潰绉?|
| `div/divu/rem/remu` | `rtl/core/div.v` | 绉讳綅銆佹瘮杈冦€佸噺娉曠殑杩唬 FSM锛岀害 32 涓?cycle | 闈㈢Н杈冨皬銆佹椂搴忓弸濂斤紱闄ゆ硶鏈熼棿鐩稿叧娴佹按鎵ц闇€绛夊緟 |

鎵€浠モ€滄敮鎸?RV32M鈥濅笉浠ｈ〃涔橀櫎鍣ㄥ凡缁?PPA 鏈€浼樸€傝嫢瑕佷紭鍖栵紝搴斿厛鐢?workload/PMU 璇佹槑涔橀櫎鏄摱棰堬紝鍐嶆瘮杈冪粍鍚堜箻娉曘€乸ipelined multiplier銆佷笉鍚?radix divider 鐨勯潰绉€佹椂搴忓拰杞欢鏀剁泭锛涗笉搴斾粎鍥犫€滄湁 AI鈥濆氨璐哥劧鍔犲叆 MAC/NPU銆?
## 4. Register銆丆ache銆丷AM/DDR锛氬閲忚秺澶э紝绂?ALU 瓒婅繙

| 瀛樺偍灞?| 鏈川/浣嶇疆 | 璋佹樉寮忎娇鐢?| 鍏稿瀷浣滅敤 |
|---|---|---|---|
| GPR register file | CPU 鍐呮牳閲岋紝`regs.v` | 鎸囦护鐨?`x0..x31` | ALU 杈撳叆銆佺粨鏋滄殏瀛橈紱RV32 姣忎釜 32 bit锛屽叡 32脳4 B=128 B锛宍x0` 鍥哄畾涓?0 |
| I/D Cache | CPU 鍐呮牳闄勮繎鐨勭‖浠剁紦瀛?| 纭欢鑷姩绠＄悊 | 缂撳瓨甯哥敤 code/data锛岄檷浣庤闂悗绔欢杩?|
| BRAM/RAM | FPGA 鐗囦笂瀛樺偍鎴?SoC memory-mapped RAM | 杞欢閫氳繃鍦板潃璁块棶 | 绋嬪簭鏄犲儚銆佹暟鎹€乻tack/heap |
| DDR | 鏉跨骇澶栭儴鍔ㄦ€佸唴瀛?| 杞欢閫氳繃鍦板潃璁块棶 | 澶у閲忕▼搴?鏁版嵁 |

瀵勫瓨鍣ㄤ笉鏄€淎LU 鏈韩鈥濓紝鑰屾槸 ALU 鏈€杩戠殑鍙紪绋嬫搷浣滄暟浠撳簱銆俙add x3,x1,x2` 浼氫粠 register file 璇?x1/x2锛孉LU 鐩稿姞锛屽啀鏈€缁堝啓鍥?x3銆?
褰撳墠閰嶇疆鐨勫彲鏍稿疄鏁板瓧锛欼-Cache = `8 words/line 脳 256 lines 脳 4 B = 8 KiB`锛汥-Cache = `8 脳 128 脳 4 B = 4 KiB`銆傞粯璁や豢鐪?ROM/RAM 鍚勪负 4096 words锛屽嵆鍚?16 KiB锛汣oreMark BRAM build 鐨?ROM 鏄?8192 words锛屽嵆 32 KiB銆傚畠浠笉鏄€滀細鐢ㄦ弧灏卞穿鈥濈殑鍥哄畾鍒嗗尯锛歝ache 婊℃椂鎸夋槧灏?鏇挎崲瑙勫垯鑵惧嚭 line锛涜蒋浠?RAM 鐪熶笉澶熸椂鎵嶆槸 stack overflow銆乭eap failure 鎴栧湴鍧€闈炴硶绛夎蒋浠?绯荤粺闂銆?
## 5. Fetch銆両-Cache銆乥urst 鍜?FENCE.I

### 5.1 IF 鐨?instruction 浠庡摢閲屾潵

```text
PC 鈫?prefetch queue / I-Cache lookup
   鈹溾攢 hit锛氱珛鍗崇粰 IF 涓€鏉?32-bit instruction
   鈹斺攢 miss锛歯ative instruction request 鈫?AXI read burst 鈫?BRAM/RAM/DDR
                                            鈫?                                      濉叆瀹屾暣 cache line
                                            鈫?                                      灏嗘墍闇€ word 缁?IF
```

I-Cache 涓嶄細鍥犱负 IF 鐢ㄨ繃涓€鏉℃寚浠ゅ氨娓呴櫎璇ユ寚浠ゃ€傝 line 浼氫竴鐩翠繚鐣欙紝鐩村埌 reset銆丗ENCE.I/invalidate锛屾垨鍙︿竴涓湴鍧€鏄犲皠鍒板悓涓€ direct-mapped index 鏃惰鏇挎崲銆?
鏈」鐩疄闄?line 鏄?8 涓?32-bit word锛氫竴娆?miss 鍙戝嚭 `ARLEN=7銆丄RSIZE=2銆両NCR` 鐨?AXI read burst锛岃繑鍥?**8 beats 脳 4 B = 32 B**锛屼笉鏄?`8脳32 B`銆傚洜姝や竴鏉?line 鍙绾?8 鏉?32-bit RV32 鎸囦护锛堣嫢鍏ㄦ槸鏍囧噯 32-bit 鎸囦护锛夈€?
### 5.2 FENCE.I

鑻?bootloader銆丏MA 鎴栬皟璇曞櫒鍒氭妸鏂版満鍣ㄧ爜鍐欏埌鏌愭鍙墽琛屽湴鍧€锛孌DR/RAM 鍐呭铏界劧鏇存柊浜嗭紝I-Cache 浠嶅彲鑳芥湁鏃?line銆俙FENCE.I` 璁?CPU invalidate I-Cache锛屼箣鍚?IF 蹇呴』閲嶆柊 fetch 鏂颁唬鐮併€傚畠涓?branch 閮戒細褰卞搷 frontend锛屼絾鏈川涓嶅悓锛?
- **branch result**锛欵X 姣旇緝鍚庡緱鍒?`taken/not-taken` 涓庢纭?target PC锛涜嫢鍜岄娴嬩笉鍚岋紝flush 閿欒矾寰勭殑鍓嶇鎸囦护锛宺edirect PC銆?- **FENCE.I**锛氫笉鏄敼鍙樻帶鍒舵祦锛岃€屾槸纭繚鈥滄柊鍐欏叆鐨勭▼搴忊€濅笉浼氳鏃?instruction cache 鍐呭閬綇銆?
## 6. Hazard锛欼PC 涓轰粈涔堜笉鎬绘槸 1

### 6.1 Data hazard 涓?forwarding

```asm
add x1, x2, x3
sub x4, x1, x5
```

`sub` 鍦?ID/EX 闇€瑕?x1 鏃讹紝`add` 鍙兘杩樻病鏈?WB銆傝嫢鍙瓑 WB锛屽繀椤诲仠寰堝鎷嶃€俙id.v` 鐨?forwarding compare `rs1/rs2` 涓庡悗绾?`rd`锛氬綋鍚庣骇纭疄浼氬啓 GPR銆乣rd != x0` 涓斿瘎瀛樺櫒鍙风浉鍚岋紝灏变互 EX/MEM/WB 鐨勬柊缁撴灉瑕嗙洊 register-file 鏃ц鍊笺€俙x0` 蹇呴』鎺掗櫎锛屽洜涓哄畠鍦ㄦ灦鏋勪笂姘歌繙鏄?0锛岀粷涓嶈兘琚€滄梺璺啓鎴愬埆鐨勬暟鈥濄€?
杩欏氨鏄负浠€涔?`add` 鐨勭粨鏋滆兘澶熺粰绱ц窡鐨?`sub` 浣跨敤锛氫笉鏄粫杩?MEM/WB鈥滄秷澶扁€濓紝鑰屾槸鍦ㄨ鏃跺埢浠庡彲鐢ㄧ殑鍚庣骇缁撴灉鎬荤嚎涓婄粫閫佸埌娑堣垂鑰呮搷浣滄暟 MUX锛沺roducer 浠嶆寜姝ｅ父娴佺▼缁忚繃 MEM/WB銆?
### 6.2 load-use interlock

```asm
lw   x5, 0(x1)
addi x6, x5, 1
```

load 鐨勭湡瀹炴暟鎹埌 MEM 鏈湡鎵嶅緱鍒帮紱绱ч殢鐨?`addi` 杩?EX 鏃舵潵涓嶅強浠?EX 杞彂銆傚洜姝?control logic 妫€娴嬪埌 `load rd == next rs` 鍚庯細鍐荤粨 PC/IF-ID銆佸 ID/EX 娉ㄥ叆涓€涓?bubble锛岀瓑 load 鏁版嵁鍙 MEM/WB forwarding 浣跨敤锛屽啀璁?`addi` 鍓嶈繘銆傝繖鏄纭€ч渶瑕佺殑涓€鎷嶆崯澶憋紝涓嶆槸 bug銆?
### 6.3 Control hazard

branch predictor 鎻愬墠鐚溾€滆烦涓嶈烦銆佽烦鍒板摢鈥濄€侲X 鎵嶇粰鍑?branch result锛涜嫢鐚滈敊锛宖ront end 鎶婇敊璇矾寰勭殑 IF/ID/prefetch 椤规竻涓?invalid/NOP锛孭C 鏀瑰埌姝ｇ‘ target銆俧lush 涓嶄細鍒犻櫎绋嬪簭瀛樺偍鍣ㄩ噷鐨?instruction锛屽彧鏄姝㈠凡缁忓彇鍒扮殑閿欒璺緞 instruction 浜х敓鍐?GPR/store 绛夊壇浣滅敤銆?
### 6.4 IPC 鐨勬纭悊瑙?
IPC = retired instructions / cycles銆傚綋鍓嶄竴娆″彲澶嶇幇 CoreMark 璁板綍绾?`318,138 / 451,235 = 0.705 IPC`锛涙澘绾у畬鏁?CoreMark 涓?2.34 CoreMark/MHz銆傝繖浜涙暟瀛椾笉鑳界敱鈥渃ache 鎴?register 婊′簡鈥濈洿鎺ヨВ閲婏細

- GPR 涓嶄細鍍忛槦鍒楅偅鏍封€滄弧鈥濓紱32 涓瘎瀛樺櫒涓嶈冻鏄紪璇戝櫒 register spilling 澧炲鐨勯棶棰樸€?- cache 婊℃槸姝ｅ父鐘舵€侊紝褰卞搷鎬ц兘鐨勬槸 **miss銆佸啿绐佸拰 refill latency**锛屼笉鏄閲忕姸鎬佹湰韬€?- CoreMark 杩樹細鍙楀埌 load-use銆乥ranch redirect銆佷箻闄ゆ硶銆乻tore wait銆両/D miss銆丄XI/BRAM/DDR backpressure 鍜屾祴璇曢厤缃奖鍝嶃€?
涓嬩竴姝ュ簲浠?PMU 鍒嗙被璁℃暟瀹氫綅鍗犳瘮锛屽啀鍐冲畾鏄惁鏀?branch predictor銆乧ache銆乻tore queue 鎴栫紪璇戦€夐」锛涗笉鑳藉彧鍑?IPC 鐩叉敼缁撴瀯銆?
## 7. Frontend锛欱TB銆丅HT 涓?prefetch queue

**鎺у埗娴佹寚浠?*鎸囦細鏀瑰彉椤哄簭 PC+4 鐨勬寚浠わ細conditional branch銆乣jal`銆乣jalr`銆乺eturn 绛夈€?
- **BTB (Branch Target Buffer)**锛氬皬鍨嬫寜 PC 绱㈠紩鐨勮〃锛屽瓨 valid/tag/target锛涘洖绛斺€滆繖鏉?PC 鏇捐烦杩囧悧锛焧arget 鏄摢閲岋紵鈥?- **BHT (Branch History Table)**锛氬瓨 2-bit 楗卞拰璁℃暟鍣紱鍥炵瓟鈥滆繖娆℃洿鍙兘 taken 杩樻槸 not taken锛熲€濊鏁板櫒閫氬父浠?strong-not-taken銆亀eak-not-taken銆亀eak-taken銆乻trong-taken 閫愭绉诲姩锛屽伓鐒朵竴娆＄粨鏋滀笉绔嬪埢缈昏浆棰勬祴銆?- **prefetch queue**锛氱紦鍐?I-Cache/鍚庣杩斿洖鐨勬寚浠ゅ拰 ID 娑堣垂涔嬮棿鐨勮妭濂忓樊锛屽噺灏?fetch starvation銆?
鏈」鐩?`branch_predictor.v` 鏄?16-entry direct-mapped BTB + 瀵瑰簲 2-bit BHT銆侭TB/BHT 涓嶆槸榄旀硶锛氬懡涓拰棰勬祴姝ｇ‘鎵嶇渷鎺?redirect锛涢娴嬮敊浠嶅繀椤?flush銆?
## 8. D-Cache 涓?2-entry store queue

store queue 鍦?[`rtl/core/dcache.v`](../rtl/core/dcache.v) 鐨?`store_buffer_*` 瀵勫瓨鍣ㄩ噷锛歚store_buffer_addr[0:1]`銆乣store_buffer_wdata[0:1]`銆乣store_buffer_wmask[0:1]`銆乭ead/tail/count銆傚畠鏄弗鏍兼湁搴忕殑 **2-entry write-through store queue**銆?
浣滅敤锛歝ache-hit store 鍦?D-Cache 涓珛鍗冲弽鏄犲叾鏋舵瀯鍙缁撴灉锛屽悓鏃跺皢鍚庣 write-through 鍐欒姹傛帓闃燂紱CPU 涓嶅繀姣忔閮界瓑澶栭儴 memory handshake銆俼ueue 婊℃椂鍚庣画 store 蹇呴』 stall锛泀ueue 涓殑 older store 蹇呴』鎸夐『搴?drain锛屼笉鑳借鏂扮殑 store 鎴?MMIO 瓒婅繃銆俵oad 鑻ヨ鍒板皻鏈啓鍥炲悗绔殑鍦板潃锛孌-Cache 鏈?store-to-load forwarding锛屼繚璇佽鍒版渶鏂板€笺€?
鏄惁鎵╁ぇ鍒?4-entry 涓嶈兘鎷嶈剳琚嬪喅瀹氥€傛纭疄楠屾槸锛歅MU 瑙傚療 `store_buffer_full_stall` 鏄惁鐪熶负鐑偣 鈫?2-entry/4-entry A/B 鈫?姣旇緝 IPC/CoreMark銆丩UT/FF銆佹椂搴忓拰鍔熻兘鍥炲綊銆傚閲忓彉澶у彲鑳芥彁楂樻寔缁?store 鍚炲悙锛屼篃鍙兘澧炲姞姣旇緝/MUX/鎺у埗锛屾伓鍖?PPA銆?
## 9. Native memory銆丄XI 涓?UVM 鍒板簳楠岃瘉浠€涔?
Cache/AXI memory subsystem 鏄粈涔?瀹冩槸 CPU 浠庘€滄墽琛屼竴鏉?lw/鍙栦竴鏉℃寚浠も€濆埌鈥滄渶缁堣闂?BRAM銆丏DR 鎴栧璁锯€濈殑鏁村瀛樺偍璁块棶绯荤粺銆?```
鍙栨寚锛?PC 鈫?prefetch queue 鈫?I-Cache 鈫?native instruction port
                               鈫?native-to-AXI4 adapter
                               鈫?AXI4 fabric 鈫?ROM / BRAM / DDR

璇诲啓鏁版嵁锛?EX 绠楀湴鍧€ 鈫?D-Cache + store queue 鈫?native data port
                                      鈫?native-to-AXI4 adapter
                                      鈫?AXI4 fabric 鈫?RAM / DDR / MMIO
```

CPU core 灏?IF/DCache 璇锋眰鎶借薄鎴?native memory ports锛?
```text
request: address, read/write, wdata, byte mask, burst length
response: ready, rdata
```

涓轰粈涔堜腑闂磋繕瑕佹湁 native interface锛?- CPU/Cache 鍙渶琛ㄨ揪锛氬湴鍧€銆佽鍐欍€佸啓鏁版嵁銆乥yte mask銆乥urst length銆乺eady銆?- native_to_axi4_master.v 鍐嶈礋璐ｅ鐞?AXI 鐨?AR/AW/W/R/B 浜斾釜閫氶亾鎻℃墜銆?- 杩欐牱 CPU 寰灦鏋勪笉浼氬拰 AXI 鍗忚缁嗚妭姝荤粦锛孋ache TB 涔熶笉蹇呭厛鎷夎捣瀹屾暣 DDR/AXI SoC銆?
### 9.1 鏈」鐩疄闄呯殑鍗忚杞崲涓庢椂閽熻竟鐣?
涓嶈鎶婅繖鏉￠摼璺悊瑙ｆ垚鈥滄墍鏈?AXI 閮藉厛鍙?AXI-Lite 鍐嶅彉 APB鈥濄€傚疄闄呯粨鏋勬槸锛?
```text
I-Cache / D-Cache native request
  鈫?native_to_axi4_master
  鈫?AXI4 fabric / crossbar
    鈹溾攢 ROM / RAM / external-memory or DDR path锛氫繚鎸?AXI4 memory transaction
    鈹斺攢 control island锛堜綆閫熷璁惧湴鍧€鍖猴級
       鈹溾攢 DMA 绛変笓鐢ㄥ瘎瀛樺櫒绐楀彛锛欰XI4 鈫?AXI4-Lite register path
       鈹斺攢 UART / timer / GPIO / SPI / I2C / PMU锛欰XI4 single-beat
          鈫?axi4_to_apb_bridge 鈫?internal AXI-Lite-style bridge 鈫?APB
```

`AXI4`銆乣AXI4-Lite` 鍜?`APB` 鏄崗璁眰娆★紝涓嶈嚜鍔ㄧ瓑浜庝笁涓椂閽熷煙銆傚綋鍓?CPU profile 涓?CPU銆丆ache銆丄XI fabric銆乧ontrol island 鍜?APB 涓昏浣跨敤鍚屼竴涓?`cpu_clk`锛屾墍浠ュ崗璁浆鎹㈡湰韬笉鏄?CDC銆傚彧鏈夋棤鍥哄畾鐩镐綅鍏崇郴鐨勬椂閽熸墠闇€瑕佸紓姝?CDC锛涙湰椤圭洰鏄庣‘鐨勫紓姝ヨ竟鐣屾槸 `jtag_TCK 鈫?cpu_clk`銆?
鑻ヤ互鍚庝负浜嗕綆鍔熻€楁妸 APB 鏀逛负 `pclk = cpu_clk/2`锛岃繖灞炰簬鍙害鏉熺殑鍚屾 generated-clock crossing锛岃€屼笉鏄ぉ鐒跺紓姝?CDC锛涗唬浠锋槸鏇存參鐨?APB access銆侀澶?generated-clock/reset 绾︽潫鍜屾洿澶?bridge 楠岃瘉銆傝嫢 `pclk` 鍙嫭绔嬪仠閽熴€丏VFS 鎴栨潵鑷彟涓€ PLL锛屾墠闇€鍗囩骇涓虹湡姝ｈ法寮傛鍩熺殑 bridge/handshake 鎴?FIFO銆?
褰撳墠 UVM DUT boundary 鏄細

```text
CPU core + I/D Cache  鈫? native memory BFM
                           鈫?                    driver / monitor / scoreboard
```

Directed UVM verification
directed 灏辨槸鈥滀汉鎵嬪啓娓呮瑕佹祴浠€涔堝満鏅€濓紝鑰屼笉鏄殢鏈虹敓鎴愬嚑涓囨潯鎸囦护纰拌繍姘斻€?褰撳墠 UVM 鐨?DUT 杈圭晫鏄細
```
CPU pipeline + I-Cache + D-Cache
              鈫?native instruction/data memory ports
       UVM memory driver / monitor / scoreboard
```
鎵€浠ュ畠涓嶆槸鍗曠函楠岃瘉 鈥淚/D Cache 鈫?native-to-AXI4 adapter鈥濄€傛洿鍑嗙‘鍦拌锛?- 褰撳墠 CPU UVM 楠岃瘉 CPU 涓?Cache 瀵?native-memory 鐨勮闂涔夛紱
- 涓嶇洿鎺ラ┍鍔?妫€鏌?AXI AR/AW/W/R/B 淇″彿锛?- AXI adapter/crossbar 搴旂敱鐙珛 AXI VIP 鎴?AXI 涓撻」 TB 楠岃瘉銆?鐜版湁 pipeline_hazard_test 宸茶鐩栵細
- EX/MEM/WB forwarding锛?- lw 鍚庣珛鍒讳娇鐢ㄧ粨鏋滅殑 load-use interlock锛?- sw 鈫?lw 鏁版嵁姝ｇ‘鎬э紱
- native memory backpressure锛?- jal 閿欒矾寰?flush锛?- jalr 閿欒矾寰?flush锛?- GPR 鏈€缁堝€笺€乵emory signature銆乭old 娆℃暟銆乺edirect 娆℃暟銆?闈㈣瘯搴旇鈥渞eusable directed UVM foundation鈥濓紝涓嶈璇粹€滃凡瀹屾垚 coverage closure 鎴?ISS differential verification鈥濄€?
瀹?*纭疄鍦ㄩ獙璇佹帴鍙ｄ氦浜?*锛屼絾涓嶆鐪嬫帴鍙ｄ俊鍙凤細driver 鍔犺浇瀹氬悜 instruction/data memory锛屽苟鍒堕€?ready/backpressure锛沵onitor 瑙傚療 fetch/data request銆乵iss銆乺edirect锛泂coreboard 妫€鏌?GPR銆乵emory signature銆乴oad-use hold 鍜?branch redirect銆傜幇鏈?`pipeline_hazard_test` 鍏蜂綋璺戜簡锛欵X/MEM/WB forwarding銆乣lw鈫抋ddi` interlock銆乣jal`/`jalr` wrong-path flush銆乻tore/load 涓?native-memory backpressure銆?
鐩墠娌℃湁瀹屾暣 ISA reference model/ISS differential test銆備弗璋ㄨ娉曟槸鈥淯VM directed verification foundation鈥濓紝涓嶈兘璇粹€滃畬鏁?UVM coverage closure鈥濇垨鈥淩TL-vs-ISS sign-off鈥濄€?
## 10. CDC锛氫笉鍚岃法鍩熷満鏅鐢ㄤ笉鍚屽伐鍏?
CDC 涓嶆槸鈥滀竴寰嬩袱鎷嶅悓姝モ€濄€傞€夋嫨鍙栧喅浜庢暟鎹搴︺€佸悶鍚愩€佹槸鍚︽瘡涓?event 閮戒笉鑳戒涪澶便€?
| 鍦烘櫙 | 甯哥敤缁撴瀯 | 鍘熷洜 |
|---|---|---|
| 鍗?bit level锛堜緥濡?enable锛?| 2FF synchronizer | 闄嶄綆浜氱ǔ鎬佷紶鎾鐜?|
| 鍗?bit pulse/event锛屽厑璁镐綆鍚炲悙 | toggle 鎴?req/ack handshake | pulse 鍙兘琚洰鏍囨椂閽熼敊杩?|
| 灏戦噺 multi-bit 鍛戒护/鍝嶅簲 | stable bundle + four-phase req/ack | 鏁版嵁淇濇寔绋冲畾鍒扮‘璁わ紝閬垮厤閫?bit 鍚屾鎾曡 |
| 楂樺悶鍚?multi-bit stream | asynchronous FIFO锛圙ray pointer锛?| 涓ょ鍙嫭绔嬭繛缁鍐?|
| async reset deassertion | 鍚勬椂閽熷煙 async assert / sync deassert reset synchronizer | 閬垮厤涓嶅悓鍩熼噴鏀?reset 閫犳垚鍋囦簨浠?|

鏈」鐩?USER2 DMI 閲囩敤绗笁绉嶏細TCK 鍩熶繚鎸?40-bit DMI request payload锛屽彂璧?req锛汣PU 鍩熺湅鍒板悓姝ュ悗鐨?req 鍚庡彧鎵ц涓€娆★紝淇濇寔 response payload锛屽啀杩斿洖 ack锛涘弻鏂瑰畬鎴?req high/ack high/req low/ack low 鐨?four-phase 鍗忚銆傚 bit 鏁版嵁娌℃湁閫愪綅鎵撲袱鎷嶏紝姝ｆ槸涓轰簡閬垮厤 data tearing銆傚畠宸叉湁 RTL/寮傛浠跨湡涓庢澘娴嬭瘉鎹紝浣嗗皻鏈畬鎴?SpyGlass CDC/RDC sign-off銆?
### 10.1 寮傛 assert銆佸悓姝?deassert 涓嶆槸 four-phase handshake

reset synchronizer 涓?DMI four-phase handshake 鍒嗗伐涓嶅悓锛氬墠鑰呰姣忎釜鏃堕挓鍩熷畨鍏ㄥ湴绂诲紑 reset锛屽悗鑰呬紶閫掍竴绗旇法鍩熻皟璇曚簨鍔°€俙rtl/utils/jtag_cdc_reset_sync.v` 鐨勬牳蹇冪粨鏋勬槸锛?
```verilog
always @(posedge clk or negedge arst_n) begin
    if (!arst_n)
        release_sync <= 2'b00;
    else
        release_sync <= {release_sync[0], 1'b1};
end
assign srst_n = release_sync[1];
```

- `arst_n` 鍙樹负 0 鏃讹紝涓嶇瓑寰呮椂閽熻竟娌垮氨娓呴浂锛?*asynchronous assertion**锛?- `arst_n` 浠?0 閲婃斁涓?1 鍚庯紝绗竴涓湰鍦?clock 涓?`00鈫?1`锛岀浜屼釜涓?`01鈫?1`锛宍srst_n` 鎵嶅彉 1锛?*synchronous deassertion**锛?- TCK 鍩熷拰 CPU 鍩熷悇鏈夎嚜宸辩殑 reset synchronizer锛岄伩鍏嶆煇涓€鍩熷厛鎭㈠鑰屾妸 reset 杈规部璇綋鎴?request/ack銆?
闈欐€?CDC/RDC 鐨勬纭瘉鎹簲鏄細SGDC 瀵?`clk`銆乣jtag_TCK`銆佸紓姝?reset 鍜?synchronizer 鍋氫簡鐪熷疄绾︽潫鍚庯紝SpyGlass 瀹屾暣璺戝畬骞堕€愭潯澶勭悊 violation/waiver銆備粎鏈?RTL銆佸紓姝ヤ豢鐪熸垨鏉挎祴锛屼笉绛変簬 static sign-off銆?
## 11. USER2 JTAG/DMI锛氫粠鐢佃剳鍒?CPU halt 鐨勯摼璺?
```text
PC / Vivado hardware manager
  鈫?board USB-JTAG cable
  鈫?FPGA internal TAP
  鈫?USER2 instruction (ZynqMP USER2 IR = 0x903)
  鈫?BSCANE2 USER2 adapter
  鈫?custom DMI transport (TCK 鈫?cpu_clk CDC)
  鈫?jtag_dm
  鈫?halt / register access / resume
```

`USER2` 鏄?FPGA 鍐呯疆 TAP 鐣欑粰鐢ㄦ埛閫昏緫鐨勪竴鏉?user-scan instruction锛沗0x903` 鏄鍣ㄤ欢閰嶇疆 TAP 閫夋嫨 USER2 鐨?12-bit instruction encoding锛屼笉鏄?RISC-V 鎸囦护銆傝繖鏍峰鐢ㄦ澘鍗?USB-JTAG锛屼笉蹇呴澶栨帴鍥涙牴澶栭儴 JTAG pin銆?
鏉挎祴楠屾敹椤哄簭涓猴細

```text
DMSTATUS = 0x00430C82  (running)
halt
DMSTATUS = 0x00430382  (halted)
abstract read x5 = 0x00000000
resume
DMSTATUS = 0x00430C82  (running)
```

杩欒瘉鏄?host transport銆丆DC銆乨ebug module 涓?CPU halt/resume 鐘舵€佽繛鎺ヨ捣鏉ヤ簡銆傝竟鐣屽繀椤讳富鍔ㄨ鏄庯細瀹冩槸鑷畾涔?USER2/DMI 鐨勬渶灏忔澘娴嬮棴鐜紝涓嶆槸瀹屾暣 RISC-V Debug Specification锛屼篃鏈仛 memory/system-bus write/Flash 鎿嶄綔銆?
### 11.1 USER2 鏉挎祴涓?static CDC 鐨勮鐩栬竟鐣?
鏉挎祴浣跨敤鐨勬槸 `BSCANE2 USER2` 璺緞锛涜€屽綋鍓?`cpu_axi_debug_profile_top` 鐨勯粯璁?SpyGlass elaboration 璁惧畾 `USE_BSCAN_USER2=0`锛岃鐩栫殑鏄?raw-JTAG debug 璺緞銆傚叾瀹為檯 reset synchronizer 灞傜骇鏄細

```text
u_soc/u_jtag_top/u_tck_reset_sync/srst_n
u_soc/u_jtag_top/u_cpu_reset_sync/srst_n
```

SGDC 宸插皢杩欎袱涓?concrete hierarchy 鍐欏叆 `reset_synchronizer` 绾︽潫锛屾浛浠ｆ棤鏁堢殑閫氶厤绗﹀悕绉般€傝 raw-JTAG CDC run **涓嶈兘**澹扮О瑕嗙洊浜?BSCANE2/USER2锛涜鍋?USER2 闈欐€?CDC锛屽繀椤诲彟寤?`USE_BSCAN_USER2=1` 鐨勯《灞?鏂囦欢鍒楄〃/SGDC profile锛屽啀绾︽潫 USER2 transport 鐨勭湡瀹炲眰绾с€?
## 12. 鏃跺簭銆丏C銆丼TA 涓?EX-to-JALR 浼樺寲鏁呬簨

### 12.1 DC/STA 鏄仛浠€涔堢殑

- **Design Compiler (DC)**锛氳 RTL銆乻tandard-cell library 鍜?SDC 绾︽潫锛屽皢 RTL 缁煎悎鎴愰棬绾х綉琛紝鍚屾椂浼扮畻 area銆佸姛鑰楃浉鍏充俊鎭拰鏃跺簭銆?- **STA (Static Timing Analysis)**锛氫笉璺戞祴璇曞悜閲忥紝鑰屾槸鏋氫妇 register-to-register銆乮nput/output 绛夋椂搴忚矾寰勶紝妫€鏌?setup/hold 鏄惁婊¤冻銆俉NS 鏄渶宸?setup slack锛孴NS 鏄墍鏈夎礋 slack 鎬诲拰锛學HS 鏄渶宸?hold slack銆?- 褰撳墠缁撴灉鏄?**28 nm pre-layout** DC/STA锛氭病鏈?placement/routing 瀵勭敓锛屽洜姝や笉鏄?ASIC sign-off銆傚畬鏁?ASIC sign-off 杩橀渶 post-layout parasitics銆佸 PVT corners銆丼I/OCV 绛夈€?
### 12.2 鍏抽敭璺緞鎬庝箞鏀?
鍘熷鐗规畩鎯呭舰鏄細EX 闃舵鍒氫骇鐢熶竴涓瘎瀛樺櫒缁撴灉锛屼笅涓€鏉?`jalr` 绔嬪嵆鎶婅瀵勫瓨鍣ㄤ綔涓鸿烦杞?base銆傜洿鎺?EX forwarding + JALR redirect 褰㈡垚寰堥暱鐨勭粍鍚?feedback cone銆?
鏀规硶锛氬彧鍦?**EX producer 鈫?immediate JALR consumer** 鐨勭壒瀹?RAW dependency 鏃舵彃鍏ヤ竴鎷?interlock锛岃 JALR 绛夊埌 MEM/WB锛屽啀浠?`reg1_late_data` 浣跨敤 MEM/WB late forwarding銆傝繖鏍风敤瀵勫瓨鍣ㄥ垏鏂簡鍘熷厛缁勫悎璺緞銆?
浠ｄ环鏄鐗规畩 JALR dependency 澶氫竴鎷嶏紱鏀剁泭鏄緝鏄撴椂搴忔敹鏁涖€傜浉鍚?5 ns timing-cone A/B 涓嬶紝鏃?cone 涓虹害 80 levels/4.90 ns锛涙浛鎹㈠悗鐨?registered path 绾?0.09 ns锛屽搴斿眬閮?setup slack +4.77 ns銆?*涓嶈璇?CPU 鍏ㄥ眬 Fmax 鎻愬崌浜?4.77 ns**锛氳繖鏄眬閮?timing-cone 瀵规瘮锛屽畬鏁?CPU 鐨?Fmax 蹇呴』浠ュ畬鏁?post-route/瀹屾暣 STA report 涓哄噯銆?
### 12.3 EX-to-JALR锛歊TL 鏉′欢銆侀€愬懆鏈熷彉鍖栦笌鍙栬垗

鍏稿瀷绋嬪簭鏄細

```asm
add  x1, x2, x3
jalr x0, 0(x1)
```

`riscv_cpu_core.v` 鐨?`jalr_ex_alu_hazard_flag` 鏈川涓婃鏌ワ細ID 鎸囦护鏄?`JALR`銆丒X 鎸囦护浼氬啓瀵勫瓨鍣ㄣ€乣EX.rd == JALR.rs1`銆佺洰鐨勫瘎瀛樺櫒涓嶆槸 `x0`锛屽苟鎺掗櫎浠嶉』鎸?load-use 瑙勫垯澶勭悊鐨?load producer銆傚懡涓椂灏嗗畠骞跺叆 `id_hazard_flag`锛岀敱 control logic hold 鍓嶇骞跺悜 ID/EX 娉ㄥ叆 bubble銆?
```text
cycle N:   add 鍦?EX 璁＄畻 x1锛沯alr 鍦?ID锛涙娴?hazard锛宩alr 涓嶈繘鍏?EX
cycle N+1: add 宸茶法瓒?EX/MEM register銆佸湪 MEM锛沯alr 浠嶅湪 ID锛屽噯澶?late value
cycle N+2: jalr 鍦?EX 浣跨敤缁忚繃娴佹按瀵勫瓨鍣ㄨ竟鐣屽悗鐨?x1锛岃绠?target 骞?resolve redirect
```

鏃ф柟妗堣 JALR 鐩存帴渚濊禆 producer 鐨?EX forwarding锛岄暱璺緞涓?`EX ALU 鈫?forwarding MUX 鈫?JALR target 鈫?redirect/PC`銆傛柊鏂规涓嶆槸鈥滃嚟绌哄姞涓€涓瘎瀛樺櫒鈥濓紝鑰屾槸澶嶇敤宸叉湁 EX/MEM銆丮EM/WB 娴佹按瀵勫瓨鍣紝璁?producer 鐨勫€兼櫄涓€鎷嶆垚涓?forwarding source锛涘洜姝や竴涓秴闀垮崟鍛ㄦ湡缁勫悎 cone 琚椂閽熻竟鐣屽垏鎴愪袱娈点€傝繖涓紭鍖栦粎褰卞搷璇ョ綍瑙?dependency锛屼笉鏀瑰彉鏅€?ALU forwarding銆乥ranch 澶勭悊鎴?load-use interlock 鐨勫熀鏈瓥鐣ャ€?
## 13. FPGA 缁撴灉銆丳PA 鍜岃瘹瀹炶竟鐣?
USER2 CPU profile 鍦?ZU15EG 100 MHz post-route 鐨勫凡绛炬敹璁板綍锛歐NS `+1.527 ns`銆乀NS `0`銆乄HS `+0.015 ns`锛岃祫婧愮害 `20.6K LUT / 16.0K FF / 16 BRAM / 4 DSP`銆傝繖璇存槑璇?profile 鍦ㄨ繖涓?FPGA 鏋勫缓/绾︽潫涓?setup 鍜?hold 閮芥敹鏁涖€?
### 13.1 鎬ц兘鏁板瓧濡備綍姝ｇ‘浣跨敤

- 鏉跨骇瀹屾暣 CoreMark 璁板綍涓?`2.34 CoreMark/MHz`锛?0 MHz銆?17 iterations/s銆?000 iterations锛夛紱瀹冩槸褰撳墠鍙鐜扮殑 benchmark 璇佹嵁銆?- PMU 瑙傛祴绐楀彛鐨?`318,138 instructions / 451,235 cycles 鈮?0.705 IPC` 鐢ㄦ潵瀹氫綅鍋滈】鏉ユ簮锛汭PC 涓?CoreMark/MHz 涓嶆槸鍚屼竴鎸囨爣锛屼笉鑳戒簰鐩哥洿鎺ユ崲绠椼€?- 鍘嗗彶鐭豢鐪熶腑鍑虹幇杩囩害 `3.19` 鐨勮繎浼兼暟鍊硷紝浣嗗叾 RTL銆乵emory 閰嶇疆銆乣SIMULATION_FAST_EXIT` 绐楀彛鍜岄獙璇佹潯浠朵笉鍚岋紝涓嶈兘涓庡綋鍓嶅畬鏁?CoreMark 瀵规瘮锛屼篃涓嶈繘鍏ョ畝鍘嗐€?
浠讳綍 PPA 浼樺寲閮藉簲褰㈡垚鍚屼竴 workload銆佸悓涓€绾︽潫涓嬬殑闂幆锛歅MU/DC/Vivado report 瀹氫綅鐡堕 鈫?鏈€灏?RTL 鏀瑰姩 鈫?directed/ISA 鍥炲綊 鈫?IPC/CoreMark銆丩UT/FF/BRAM/DSP銆乄NS/TNS 鐨?A/B銆傛病鏈?matched SRAM macro 鐨勫畬鏁?cache-inclusive 28 nm 缁撴灉鏃讹紝涓嶅簲浼€?ASIC area/Fmax 鏁板瓧銆?
PPA 鏄?**Performance / Power / Area**锛?
- Performance锛氶鐜囥€乻lack銆両PC銆乥enchmark锛?- Power锛氬垏鎹㈡椿鍔ㄣ€佹椂閽熴€佸瓨鍌ㄨ闂喅瀹氾紝褰撳墠娌℃湁 sign-off power锛?- Area锛欶PGA 鐨?LUT/FF/BRAM/DSP锛孉SIC 鐨?cell/macro area銆?
鎻愬崌 PPA 涓嶆槸鈥滄妸鎵€鏈?buffer 鍔犲ぇ鈥濄€備緥濡傛洿澶?BTB銆乻tore queue銆乧ache 浼氬噺灏戦儴鍒?stall锛屽嵈澧炲ぇ SRAM/FF/MUX/姣旇緝鍣紱搴斾互 PMU 鎵剧摱棰堝悗鍋?A/B锛屽苟鍚屾椂澶嶈窇鍔熻兘鍜?post-route/DC銆?
## 14. 瀹為檯杩愯涓庢尝褰㈠涔犱换鍔?
鐜版湁 `pipeline_hazard_test` 鐨勭▼搴忓湪 `verify/uvm_cpu/tb/cpu_core_if.sv`锛屽寘鍚細

```text
addi x1, x0, 5
addi x2, x1, 7          # forwarding
add  x3, x2, x1
...
sw   x5, 0(x6)
lw   x7, 0(x6)
addi x8, x7, 1          # load-use interlock
jal  x0, +8             # wrong path must flush
...
jalr x0, 0(x10)         # wrong path must flush
```

鍦?Windows Vivado/XSim 杩愯锛?
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_cpu_uvm_smoke.ps1 -TestName pipeline_hazard_test
```

瀛︿範娉㈠舰鏃朵紭鍏堝姞鍏ワ細`clk`銆乣rst`銆丳C銆両F/ID instruction銆両D/EX instruction銆乣hold_flag`銆乣jump/flush`銆乣mem_ex_req_o`銆乣mem_ex_ready_i`銆乣mem_pc_req_o`銆乣mem_pc_ready_i`銆乣perf_branch_redirect_o`銆乣perf_dcache_load_miss_stall_o`銆乣perf_store_buffer_*`銆丒X/MEM/WB 鐨?`reg_we/rd/wdata`銆?
浣犲簲鑳藉湪娉㈠舰涓垎杈細

1. **姝ｅ父 branch 娴佽繃 MEM/WB**锛氭暟鎹粛鏇存柊锛屼絾 `reg_we=0`/`mem_we=0`锛?2. **bubble**锛氳娉ㄥ叆鐨勬棤鍓綔鐢?NOP 鍚戝悗娴佸姩锛?3. **stall**锛歅C銆両F/ID 绛夊瘎瀛樺櫒鍦ㄨ嫢骞叉媿淇濇寔涓嶅彉锛?4. **flush**锛氶敊璇矾寰勫墠绔」鍙?invalid/NOP锛孭C 鏀逛负姝ｇ‘ target銆?
## 15. 闈㈣瘯甯搁棶闂锛氱畝娲佷笖鍑嗙‘鐨勫洖绛?
**Q锛氳繖鏄?Harvard 杩樻槸 von Neumann锛?*
CPU 鍐呴儴鏈夌嫭绔?I-Cache 鍜?D-Cache/native ports锛屽洜姝ゅ墠绔憟 Harvard-like锛涗笅娓?AXI fabric/DDR 鏄叡浜?memory-mapped 绌洪棿锛屾墍浠ヤ笉鏄畬鍏ㄧ墿鐞嗗垎绂荤殑 Harvard machine銆?
**Q锛欰XI 鏀寔 OoO/multi-outstanding 鍚楋紵**
褰撳墠 SoC crossbar 鏄崟鍏ㄥ眬 outstanding锛屼笉鏀寔 AXI ID銆佸 outstanding 鎴栬法 ID OoO銆侫XI4 鏍囧噯鏈韩鏀寔 ID 鍜屽涓?outstanding锛汚XI4 绉婚櫎鐨勬槸 write-data interleaving 鐨?WID锛屼笉鏄?ID銆傚綋鍓嶅疄鐜版槸涓哄彲楠岃瘉鎬у拰闆嗘垚鑼冨洿鍋氱殑绠€鍖栥€?
**Q锛氫负浠€涔?IPC 灏忎簬 1锛?*
鍗曞彂灏勪簲绾ч『搴忔牳鐨勭悊鎯?IPC 鎵嶆槸 1銆傜湡瀹?workload 浼氬洜 cache miss銆乴oad-use銆乥ranch redirect銆佷箻闄ゆ硶鍜屾€荤嚎 backpressure 娑堣€?cycle銆傚簲浠?PMU 鍒嗛」璁℃暟鍒ゆ柇锛岃€岄潪浠呯湅涓€涓€?IPC銆?
**Q锛歎VM 鍋氬埌浠€涔堢▼搴︼紵**
宸茬粡鏄?core native-memory boundary 鐨?reusable directed UVM foundation锛屾湁 sequence/driver/monitor/scoreboard/coverage/SVA 涓?XSim/VCS smoke銆乭azard 鍥炲綊銆傚皻鏈仛 constrained-random closure銆佸畬鏁?coverage closure銆両SS differential 鎴栭潤鎬?sign-off銆?
**Q锛欳DC 濡備綍淇濊瘉 40-bit DMI 涓嶆挄瑁傦紵**
涓嶇敤閫愪綅 2FF锛涙簮绔ǔ瀹氫繚鎸?bundle锛岀敤 2FF 鍚屾鐨?req/ack 鍥涚浉鎻℃墜浼犻€?ownership锛屽畬鎴愬墠绂佹瑕嗙洊 payload锛況eset 鍦ㄥ悇鍩熷悓姝ラ噴鏀俱€?
## 16. 涓変釜澶嶄範闃舵

### 闈㈣瘯鍓?10 鍒嗛挓

澶嶄範绗?0銆?銆?銆?1銆?2銆?5 鑺傦紱鑳界敾 CPU鈫扖ache鈫扐XI鈫抦emory 鍜?PC鈫払TB/BHT鈫扞F 鐨勪袱寮犲浘銆?
### 闈㈣瘯鍓?1 灏忔椂

椤虹潃绗?1 鑺傛枃浠跺湴鍥捐 `id.v` forwarding銆乣ctrl.v` interlock/flush銆乣dcache.v` store queue銆乣jtag_user2_dmi_transport.v` handshake锛涗翰鑷窇涓€娆?UVM hazard test銆?
### 鑳芥繁鍏ヨ璁虹殑绋嬪害

鍥炵瓟姣忛」鏃堕兘鎸夆€滈棶棰?鈫?RTL 鏈哄埗 鈫?楠岃瘉璇佹嵁 鈫?浠ｄ环/杈圭晫鈥濆洓姝ヨ銆備笉瑕佹妸 directed UVM 璇存垚 closure锛屼笉鎶?DC pre-layout 璇存垚 ASIC sign-off锛屼篃涓嶆妸 custom USER2 DMI 璇存垚瀹屾暣 RISC-V Debug Spec銆?
## 17. AXI4 crossbar 涓?control-plane 杈圭晫

CPU 鍐呴儴鐨?native port 涓嶆槸 AXI锛涘畠鍙〃杈锯€滃湴鍧€銆佽/鍐欍€佹暟鎹€乥yte mask銆乥urst length銆乺eady鈥濄€俙native_to_axi4_master.v` 璐熻矗鎶婅繖涓€绠€娲佹帴鍙ｇ炕璇戜负 AXI4 鐨勪簲涓?channel锛?
```text
read : native request 鈫?AR 鈫?R
write: native request 鈫?AW + W 鈫?B
```

`axi4_crossbar.v` 鍐嶅皢 CPU I-cache銆丆PU D-cache銆丏MA 绛?master 鐨勮姹傝矾鐢卞埌 ROM銆丷AM銆乪xternal memory/DDR 鎴?AXI control island銆傛帶鍒跺矝涓婃父鎺ユ敹 AXI4锛汥MA 绛変笓鐢ㄧ獥鍙ｈ繘鍏?AXI4-Lite register wrapper锛岃€岄€氱敤浣庨€熷璁剧敱 `axi4_to_apb_bridge` 鎶婂崟鎷?AXI4 璁块棶杞崲鎴?APB transaction銆侰PU 涓嶇洿鎺ラ潰瀵?APB 鐨?setup/access 鏃跺簭銆?
褰撳墠瀹炵幇鐨勭湡瀹炴€ц竟鐣岋細crossbar 閲囩敤鍗曞叏灞€ outstanding transaction銆傚畠瓒充互瑙ｉ噴 cache/AXI 鏁版嵁娴佸拰 backpressure锛屼絾娌℃湁 AXI ID銆佸 outstanding銆乺ead response interleaving 鎴?cross-ID OoO銆傞潰璇曟椂鍙鈥淎XI4-compatible integration path鈥濓紝涓嶈璇粹€滈珮骞跺彂 commercial AXI fabric鈥濄€?
## 18. PMU锛氫粠璁℃暟鍣ㄥ埌鎬ц兘鍒ゆ柇

### 18.1 澶栬涓庢帶鍒跺钩闈㈠湴鍥?
澶栬涓嶅湪 CPU 浜旂骇娴佹按鍐咃紱CPU/DMA 缁?AXI control island 鍜?APB register bank 瀵瑰畠浠繘琛?memory-mapped 璁块棶銆傞潰璇曟椂搴旀妸鈥滃鍥?IP 鍔熻兘鈥濆拰鈥滃綋鍓?CPU 鏍歌兘鍔涒€濆垎寮€琛ㄨ堪锛欳PU 璐熻矗鍙戣捣鏈夊簭 load/store锛屽璁捐礋璐ｅ鍦板潃瑙ｇ爜鍚庣殑瀵勫瓨鍣ㄨ涔夊拰澶栭儴 pin 鏃跺簭銆?
| 妯″潡 | 涓昏 RTL | 鍔熻兘 | 鏁版嵁/鎺у埗璺緞 | 闈㈣瘯杈圭晫 |
|---|---|---|---|---|
| APB subsystem | `apb_perips.v` | APB 鍦板潃璇戠爜銆佸璁惧瘎瀛樺櫒闆嗘垚 | AXI4-to-APB bridge 鈫?`PADDR/PWRITE/PWDATA` 鈫?peripheral | 浣庨€?control plane锛屼笉鏄?cacheable memory path |
| DMA | `dma.v`銆乣dma_axil_wrapper.v` | memory-to-memory transfer 涓庡瘎瀛樺櫒閰嶇疆 | AXI4-Lite control registers锛涗綔涓?AXI master 璁块棶 memory fabric | 涓嶆妸瀹冭鎴?coherent DMA锛沜ache software management 鏄嫭绔嬮棶棰?|
| UART | `uart.v` | serial TX/RX 涓庡瘎瀛樺櫒璁块棶 | APB register 鈫?UART pin | 鏉跨骇 UART smoke 鏄?CPU 鎵ц璇佹嵁涔嬩竴 |
| timer / CLINT | `timer.v`銆乣clint.v` | timer register銆乻oftware/timer interrupt source | APB/CSR control 鈫?interrupt flag 鈫?CPU | 浠呮寜瀹為檯 machine-level 鏈€灏忚矾寰勮〃杩帮紝涓嶅じ澶у畬鏁?privileged platform |
| GPIO / SPI / I2C / QSPI | 鐩稿簲 `rtl/perips/*.v` | 閫氱敤 GPIO 涓庝覆琛屽璁炬帶鍒?| APB registers 鈫?pin-level controller | 鍗忚鎺у埗 IP锛屼笉绛夊悓浜庨珮閫?coherent interconnect |
| PMU | `pmu.v` | 瑙傚療 perf event銆佹彁渚?64-bit counter | CPU/Cache `perf_*` 鈫?APB readout | 鍙娴嬶紝涓嶆敼鍙?CPU 鍔熻兘鍐崇瓥 |

鎺ㄨ崘鐨勬帶鍒堕潰鍦板潃鐞嗚В鏄細CPU data request 鈫?AXI fabric 鈫?control island锛汥MA 绛変笓鐢ㄧ獥鍙ｅ彲鎺?AXI4-Lite register wrapper锛岄€氱敤浣庨€?register 鍒欑粡 AXI4-to-APB bridge銆傚綋鍓?crossbar 鍙湁鍗曞叏灞€ outstanding锛屽洜姝や竴涓參 APB access 浼氬崰鐢ㄥ叡浜?transaction 妲戒綅锛涜繖姝ｆ槸鈥滃璁鹃鐜?鏃堕挓鍩熸敼閫犫€濅細褰卞搷绯荤粺绾ф€ц兘鐨勫師鍥犮€?
PMU 鏄?memory-mapped 鐨勮瀵熸ā鍧楋紝涓嶅弬涓?PC銆佽瘧鐮併€丆ache 鎴?AXI 鐨勫姛鑳藉喅绛栥€傚畠瑙傚療 CPU/Cache/鎬荤嚎鍙戝嚭鐨?perf_* 淇″彿锛屽苟缁存姢涓€鎵?64-bit counter銆?
CPU/Cache 鎶?`perf_*` 淇″彿瀵煎嚭锛孲oC 鎶婂畠浠帴鍒?APB PMU register bank锛涜蒋浠惰鍙栬鏁板櫒鍗冲彲寰楀埌鎬ц兘鐢诲儚銆?
64-bit counter 渚嬪锛?
```text
PMU_CYCLE                  鈫?鎬诲懆鏈?PMU_INST                   鈫?WB 闃舵鐨勬湁鏁?instruction 璁℃暟
PMU_ICACHE_MISS            鈫?instruction cache miss
PMU_DCACHE_LOAD_MISS_STALL 鈫?load refill 瀵艰嚧鐨勫仠椤?PMU_BRANCH_REDIRECT        鈫?branch/JAL/JALR 棰勬祴鎴栫洰鏍囨仮澶?PMU_STORE_BUFFER_FULL_STALL鈫?store queue 婊″鑷寸殑鍋滈】
PMU_FETCH/DATA_BUS_WAIT    鈫?涓嬫父 ready/backpressure 绛夊緟
```
RTL 鏁版嵁娴?```
riscv_cpu_core
  鈫?perf_icache_miss_o / perf_branch_redirect_o / ...
  鈫?soc_top
  鈫?apb_perips
  鈫?pmu
  鈫?APB memory-mapped registers
```
鍦?CPU 涓紝perf_inst_o = wb_inst_o锛屽洜姝?instruction counter 瑙傚療 WB 闃舵鐨勯潪 NOP 鎸囦护锛屾槸涓€涓緝鎺ヨ繎 retirement 鐨勭矖绮掑害鎸囨爣銆?PMU 鍐呴儴灏辨槸鏉′欢璁℃暟锛?```
if (icache_miss_i)
    icache_miss_counter <= icache_miss_counter + 64'd1;

if (branch_redirect_i)
    branch_redirect_counter <= branch_redirect_counter + 64'd1;
```
杞欢閫氳繃 APB 鏄犲皠瀵勫瓨鍣ㄨ鍙栥€侾MU 鍦?APB 鐨勯€夋嫨鍙锋槸 4锛屽唴閮ㄥ亸绉诲锛?```
0x04  cycle
0x0c  instruction
0x54  I-Cache miss
0x5c  D-Cache load miss
0x68  branch redirect
0x84  D-Cache load-miss stall
0x94  store-buffer-full stall
```
闃呰鎬ц兘鏃舵寜姝ら『搴忥細鍏堢畻绮楃矑搴?`IPC = PMU_INST / PMU_CYCLE`锛屽啀鐪?miss銆乺edirect銆乴oad-use hold銆乻tore wait銆乥us wait 鐨勫崰姣斻€傝嫢 D-Cache miss 鏄富鍥狅紝搴斾紭鍏堢爺绌?cache line/refill/甯冨眬锛涜嫢 redirect 鏄富鍥狅紝鍐嶇爺绌?predictor锛涜嫢 store-buffer-full 寰堝皯锛屾墿澶?store queue 娌℃湁渚濇嵁銆?tips:
`sw 鈫?lw 鏁版嵁姝ｇ‘鎬锛歴tore 鍏堟洿鏂?D-Cache锛屽苟鎶?write-through 璇锋眰鏀捐繘 store queue锛涘鏋滃悗缁?lw 璇诲悓涓€鍦板潃銆佽€岃 store 杩樻病鍐欏埌鍚庣锛孌-Cache 浼氱敤 store-to-load forwarding 杩斿洖鏈€鏂版暟鎹紝淇濊瘉杞欢鐪嬪埌鐨勯『搴忔纭€?
## 19. Directed UVM foundation

### 19.1 涓轰粈涔堝彨 directed

鏈」鐩笉鏄€滈殢鏈虹敓鎴愮▼搴忥紝鐒跺悗鏈熸湜闅忔満瑕嗙洊鎵€鏈?hazard鈥濄€傛瘡涓?test 閮芥槑纭斁鍏ヤ竴娈靛皬绋嬪簭鍜岄鏈熺粨鏋溿€備緥濡?pipeline hazard sequence 涓汉涓哄畨鎺掞細

```asm
addi x1, x0, 5
addi x2, x1, 7          # EX forwarding
add  x3, x2, x1
sw   x5, 0(x6)
lw   x7, 0(x6)
addi x8, x7, 1          # load-use interlock
jal  x0, +8             # wrong path flush
jalr x0, 0(x10)         # indirect redirect + flush
```

杩欑被 test 鐨勪紭鐐规槸锛氫竴涓け璐ョ殑娉㈠舰闈炲父瀹规槗瀹氫綅锛涘畠閫傚悎 CPU 椤圭洰绗竴闃舵寤虹珛鍙俊璇佹嵁銆傜己鐐规槸瑕嗙洊鑼冨洿鏈夐檺锛屽洜姝や笉鑳界敤瀹冨０绉?fully-random 鎴?full-coverage verification銆?
### 19.2 UVM 缁勪欢鍒嗗伐

```text
sequence 鈫?鐢熸垚娴嬭瘯鎰忓浘锛坧rogram kind銆乥ackpressure锛?sequencer鈫?璋冨害 transaction
driver   鈫?瑁呰浇 instruction/data memory锛屾柦鍔?reset 涓?ready 寤惰繜
monitor  鈫?瑙傛祴 fetch/data request銆乺edirect銆丆ache miss 绛変簨浠?scoreboard 鈫?姣斿鏈€缁?GPR銆乵emory signature 涓庝簨浠舵鏁?coverage 鈫?璁板綍鍏抽敭 scenario 鏄惁琚Е鍙?SVA      鈫?绾︽潫 native request/response 绛変笉鍙繚鍙嶆€ц川
```

褰撳墠 DUT boundary 鏄?**CPU core + I/D Cache 鈫?native-memory BFM**銆傚洜姝?UVM 鍚屾椂楠岃瘉浜?Cache 鐨勮姹傘€乥urst銆乵iss/backpressure 涓嬬殑 CPU 璇箟锛屼絾涓嶇洿鎺ラ獙璇?AXI AR/AW/W/R/B 淇″彿锛沘dapter/crossbar 鐨?AXI 鍗忚搴旂敱鐙珛 AXI VIP/sanity TB 瑕嗙洊銆?
### 19.3 褰撳墠 directed UVM 鐨勬鏌ョ煩闃?
| 鍦烘櫙 | driver 鍒烘縺 | monitor/scoreboard 鐨勪富瑕佹鏌?| 褰撳墠杈圭晫 |
|---|---|---|---|
| EX/MEM/WB forwarding | 鐩搁偦 ALU dependency | 鏈€缁?GPR 鍊笺€侀敊璇?forwarding 涓嶅啓 x0 | CPU pipeline |
| load-use | `lw` 鍚庣珛鍗虫秷璐?| hold銆乥ubble銆佹渶缁?GPR 姝ｇ‘ | CPU + D-Cache |
| `sw 鈫?lw` | 鍚屽湴鍧€ store/load | memory signature 涓?store-to-load forwarding | D-Cache/native memory |
| JAL/JALR redirect | 棰勭疆閿欒璺緞 instruction | redirect 娆℃暟銆侀敊璇矾寰勬棤 GPR/store 鍓綔鐢?| frontend/pipeline |
| backpressure | native ready/response 寤惰繜 | request 淇濇寔銆佹棤閲嶅/涓㈠け璁块棶銆佹渶缁堢姸鎬?| native-memory boundary |

鍥犳瀹冩棦妫€鏌ユ帴鍙?transaction锛屼篃妫€鏌?transaction 鑳屽悗鐨?CPU 鏋舵瀯缁撴灉锛涗絾瀹?*涓嶇洿鎺ユ浛浠?* AXI protocol checker銆乧ache-coherence 楠岃瘉銆両SS differential 鎴?coverage closure銆?
涓昏浣嶇疆锛歚verify/uvm_cpu/agent/`銆乣env/`銆乣formal/`銆乣tb/`銆乣tests/`銆?
## 20. 楠岃瘉鐘舵€併€佽鐩栦笌鍥炲綊杈圭晫

宸插缓绔嬪苟璺戦€氱殑楠岃瘉璇佹嵁搴旇繖鏍风悊瑙ｏ細

| 鑼冨洿 | 褰撳墠璇佹嵁 | 涓嶈兘鎺ㄥ鍑虹殑缁撹 |
|---|---|---|
| CPU UVM smoke | XSim/VCS 瀹氬悜 smoke锛宻coreboard PASS | 涓嶆槸鍏?ISA 闅忔満楠岃瘉 |
| Pipeline hazard | forwarding銆乴oad-use銆丣AL/JALR redirect銆乶ative backpressure | 涓嶆槸鍏ㄧ粍鍚?hazard coverage closure |
| JTAG DMI | 涓撻」 transport TB + ZU15EG halt/read/resume 鏉挎祴 | 涓嶆槸瀹屾暣 RISC-V Debug Spec |
| CDC | four-phase handshake RTL銆佸紓姝ユ椂閽熶豢鐪熴€乺eset synchronizer | 涓嶆槸 SpyGlass CDC/RDC sign-off |
| DC/STA | 28 nm pre-layout timing cone A/B | 涓嶆槸 post-layout ASIC sign-off |

鍚庣画鑻ヨ蛋 CPU DV 璺嚎锛屾渶鑷劧鐨勫闀块『搴忔槸锛氬鍔?cache backpressure test 鈫?interrupt test 鈫?JTAG halt/resume UVM test 鈫?reference ISS/DPI differential test 鈫?constrained-random / coverage closure銆?
## 21. 娉㈠舰闃呰锛歯ormal銆乥ubble銆乻tall銆乫lush

闃呰娉㈠舰鏃讹紝涓嶈鍙湅 `inst`锛岃繕瑕佸苟鎺掔湅 PC銆両F/ID銆両D/EX銆丒X/MEM銆丮EM/WB銆乣hold_flag`銆乣jump/flush`銆乣reg_we`銆乣mem_we`銆乣mem_req/ready`銆?
| 鐜拌薄 | 娉㈠舰鏈川 | 渚嬪瓙 |
|---|---|---|
| normal | 鍚勬祦姘村瘎瀛樺櫒姣忔媿杩涘叆涓嬩竴鏉℃湁鏁?instruction | 杩炵画 `addi` |
| bubble | 鏌愪竴绾ц鍐欏叆 NOP/invalid锛屽壇浣滅敤鍏ㄥ叧 | load-use interlock 鍚?ID/EX 娉ㄥ叆 bubble |
| stall | 鏌愪簺瀵勫瓨鍣ㄤ繚鎸佸墠涓€鎷嶆暟鎹笉鍙?| cache miss/backpressure 鏃?PC銆両F/ID hold |
| flush | 閿欒矾寰勫墠绔」澶辨晥锛孭C 鏀逛负 redirect target | branch/JAL/JALR 棰勬祴閿欒 |

鏈€鎺ㄨ崘鐨勭涓€涓尝褰㈠懡浠わ細

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_cpu_uvm_smoke.ps1 -TestName pipeline_hazard_test
```

鍏堝湪杩欐娉㈠舰閲屾壘鍒?`lw x7` 鍜岀揣闅忓叾鍚庣殑 `addi x8,x7,1`锛氫綘搴旇鐪嬪埌鍓嶇琚?hold 涓€鎷嶃€両D/EX 鍑虹幇 bubble锛岄殢鍚?`x8` 寰楀埌姝ｇ‘缁撴灉銆傚啀瀹氫綅 `jal`/`jalr`锛岃瀵熼敊璇矾寰?instruction 娌℃湁鍐?GPR銆?
## 22. 闈㈣瘯鏃跺浣曡〃杩?PPA 璇佹嵁

搴旇鎸夆€滃疄鐜版潯浠?鈫?鎸囨爣 鈫?鍚箟 鈫?闄愬埗鈥濆洓姝ヨ锛?
> 鍦?ZU15EG CPU+AXI+PMU+USER2 debug profile 涓婏紝鎴戝畬鎴愪簡 100 MHz post-route锛屽疄鐜扮粨鏋?WNS +1.527 ns銆乀NS 0銆乄HS +0.015 ns锛涜鏄庤 FPGA profile 鍦ㄨ绾︽潫涓?setup/hold 鍧囨敹鏁涖€?8 nm Design Compiler 鐨勭粨鏋滄槸 pre-layout timing-cone A/B锛岀敤浜庡畾浣嶅拰浼樺寲 EX-to-JALR 璺緞锛岃€屼笉鏄?ASIC sign-off PPA銆?
涓嶈鍋氫笁绉嶅じ澶э細

1. 涓嶆妸 FPGA LUT/BRAM 璇存垚 ASIC area锛?2. 涓嶆妸 pre-layout DC 璇存垚 post-layout sign-off锛?3. 涓嶆妸灞€閮?`+4.77 ns` cone slack 璇存垚鏁翠釜 CPU 鐨?global Fmax 鎻愬崌銆?
## 23. 闈㈣瘯琛ㄨ揪妯℃澘涓庡凡鐭ラ檺鍒?
### 23.1 90 绉掗」鐩粙缁?
> 鎴戝仛鐨勬槸 LumenRV32锛屼竴涓彲缁煎悎鐨?RV32IM 鍗曞彂灏勪簲绾ф祦姘?CPU銆傚井鏋舵瀯涓婂疄鐜颁簡 forwarding銆乴oad-use interlock銆乥ranch redirect/flush銆両/D Cache銆丅TB/2-bit BHT銆乸refetch queue 鍜?write-through store queue銆傚瓨鍌ㄨ矾寰勯噰鐢?CPU native-memory interface 鍐嶉€傞厤鍒?AXI4锛屼娇 cache/pipeline 涓?AXI protocol 瑙ｈ€︺€傞獙璇佷笂鎴戝缓绔嬩簡 native-memory boundary 鐨?SystemVerilog directed UVM foundation锛岃鐩?forwarding銆乴oad-use銆丣AL/JALR flush 鍜?backpressure銆傚伐绋嬩笂锛屾垜澶嶇敤 ZU15EG 鐨?USER2 JTAG 瀹炵幇浜嗚嚜瀹氫箟 DMI transport锛屽苟閫氳繃 four-phase CDC 瀹屾垚 halt銆丟PR read銆乺esume 鐨勬澘娴嬶紱鍙﹀鍩轰簬 DC timing report 瀵?EX-to-JALR dependency 鍋氫竴鎷?interlock 鍜?MEM/WB late-forwarding 閲嶆瀯锛屾秷闄や簡闀跨粍鍚堝叧閿?cone銆?
### 23.2 蹇呴』涓诲姩浜や唬鐨勯檺鍒?
- 鍗曞彂灏勩€侀『搴忔牳锛涗笉鏄?superscalar / OoO core锛?- AXI fabric 鐩墠涓嶆敮鎸?ID銆佸 outstanding 鎴?OoO response锛?- UVM 鏄?directed foundation锛屼笉鏄?coverage closure 鎴?ISS differential锛?- USER2 DMI 鏄?custom debug transport锛屼笉鏄?full RISC-V Debug Spec锛?- CDC/RDC 鏈畬鎴愰潤鎬?sign-off锛?8 nm 缁撴灉鏄?pre-layout銆?
鎶婇檺鍒惰娓呮涓嶄細鍑忓垎锛屽弽鑰岃瘉鏄庝綘鐭ラ亾宸ョ▼楠屾敹鐨勮竟鐣屻€?
## 24. 杩介棶娓呭崟銆佽瘉鎹笌涓嶈兘澶稿ぇ鐨勮〃杩?
### 24.1 鐢ㄢ€滈棶棰?鈫?璇佹嵁 鈫?杈圭晫鈥濆洖绛?
| 闈㈣瘯杩介棶 | 搴旀嬁鍑虹殑椤圭洰璇佹嵁 | 蹇呴』淇濈暀鐨勮竟鐣?|
|---|---|---|
| forwarding/load-use/flush 鎬庝箞淇濊瘉姝ｇ‘锛?| `id.v`/`ctrl.v` hazard 鏉′欢銆乣pipeline_hazard_test` 鐨?GPR銆乭old銆乺edirect 妫€鏌?| 瀹氬悜鍦烘櫙閫氳繃锛屼笉鏄墍鏈?ISA 缁勫悎鐨?closure |
| Cache 鍒?DDR/澶栬濡備綍璁块棶锛?| `icache.v`/`dcache.v`銆乣native_to_axi4_master.v`銆乧rossbar/control-island 璺緞 | 褰撳墠 crossbar 鍗曞叏灞€ outstanding锛屾棤 AXI ID/OoO |
| JTAG 涓轰粈涔堜笉浼氭挄瑁?40-bit 鍛戒护锛?| payload stable + req/ack 2FF 鍥涚浉鎻℃墜銆乤sync-clock TB 涓?USER2 鏉挎祴 | custom DMI锛屼笉鏄畬鏁?RISC-V Debug Spec |
| reset/CDC 鏄惁绛炬敹锛?| reset synchronizer RTL銆丼GDC銆丼pyGlass 瀹屾暣鏃ュ織鍜?violation/waiver | 鏈嚭鐜?fresh clean report 鍓嶅彧鑳借 flow 宸插缓绔嬶紝涓嶈兘璇?CDC/RDC clean |
| 鏃跺簭浼樺寲鏄惁鎻愰珮鏁存牳棰戠巼锛?| 鍚?5 ns DC timing-cone A/B銆佸畾鍚?RTL/bare-metal 鍥炲綊 | `+4.77 ns` 鏄眬閮?cone slack锛屼笉鏄?global Fmax |
| FPGA 鏄惁鐪熻窇杩囷紵 | 100 MHz post-route WNS/TNS/WHS 涓?USER2 halt/read/resume 鏉挎祴璁板綍 | 璇?profile/绾︽潫涓嬬殑缁撴灉锛屼笉鑳藉鎺ㄤ负 ASIC PPA |

### 24.2 杩樺簲涓诲姩鍑嗗鐨勫崄涓拷闂?
1. 涓轰粈涔堜簲绾с€佸崟鍙戝皠銆乮n-order 鐨勭悊璁?IPC 涓婇檺绾︿负 1锛?2. `lw` 鍚庣揣璺熶娇鐢ㄤ负浣曟櫘閫?forwarding 涓嶅锛岃€?`add 鈫?sub` 鍙互 bypass锛?3. branch prediction 鍦ㄤ綍鏃堕娴嬨€佸湪浣曟椂 resolve锛涢娴嬮敊 flush 鍝簺鍓嶇鐘舵€侊紵
4. I/D Cache 鐨勫閲忋€乴ine size銆乨irect-mapped conflict 涓?write-through 鐨勫彇鑸嶆槸浠€涔堬紵
5. `sw 鈫?lw` 鍚屽湴鍧€濡備綍鐪嬭鏈€鏂版暟鎹紝store queue 涓轰粈涔堝繀椤讳弗鏍兼湁搴忥紵
6. `FENCE.I` 涓?branch flush 鍒嗗埆瑙ｅ喅浠€涔堥棶棰橈紵
7. native memory interface 涓轰粈涔堝瓨鍦紱AXI 鐨?AR/AW/W/R/B 濡備綍琚?adapter 灞忚斀锛?8. UVM 鐨?DUT boundary 鏄粈涔堬紱scoreboard 涓轰粈涔堟棦鐪嬫帴鍙?transaction 鍙堢湅鏋舵瀯鏈€缁堢姸鎬侊紵
9. four-phase handshake 浣曟椂姣?async FIFO 鍚堥€傦紱async assert/sync deassert 鍒嗗埆瑙ｅ喅浠€涔堥闄╋紵
10. DC pre-layout銆丗PGA post-route銆丄SIC sign-off 涓夎€呯殑璇佹嵁绛夌骇鍜屼笉鍙浛浠ｆ€э紵

### 24.3 寮€婧愭潵婧愪笌涓汉璐＄尞鐨勫噯纭〃杈?
浠ｇ爜鍩虹嚎鏉ヨ嚜 Apache-2.0 鐨?TinyRISCV锛岀浉鍏崇増鏉冨ご銆乣LICENSE` 鍜?`NOTICE` 蹇呴』淇濈暀銆傞潰璇曚腑鍙噯纭鑷繁鐨勮础鐚泦涓湪 CPU/SoC 闆嗘垚銆乧ache/AXI memory path銆侀獙璇佹鏋躲€乁SER2 DMI debug銆丗PGA/STA flow 鍜屾枃妗ｏ紱涓嶈鎶婁笂娓告墍鏈夊熀纭€ CPU RTL 鍏ㄩ儴琛ㄨ堪涓轰粠闆跺師鍒涖€?
