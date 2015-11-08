%% 简介：系统基于布林通道原理，是一个趋势追踪系统。
%  入场条件：
%    ROC大于0且价格突破布林带上轨就开多仓；
%    ROC小于0且价格跌破布林带下轨就开空仓；
%  关键参数：
%	 买卖滑点参数Slip
%	 布林带的周期数BollLength；
%    布林带标准差的倍数Offset;
%    ROC的周期数ROCLength；
%    跟踪止损算法的周期数ExitLength;


%% --提取数据--

% user=input('请输入数据库用户名：','s');
% password=input('请输入数据库密码：','s');
% commodity=input('请输入商品(如RB888)：','s');
% Freq=input('请输入周期(如M5)：','s');
% conna=database('Futures_matlab',user,password);
% cursor=exec(conna,strcat('select * from ',32,commodity,'_',Freq));%32是指空格的ASCLL码
% cursor=fetch(cursor);
% data=cursor.Data;

commodity = 'RB888';
Freq = 'M15';
%load data.mat;
data =load('rb000_day.csv');
data_1min = load('rb000_dayfivemin.csv');

Date=x2mdate(data(:,1),0);    %日期时间
Open=data(:,2);               %开盘价
High=data(:,3);               %最高价
Low=data(:,4);                %最低价
Close=data(:,5);              %收盘价
Volume=data(:,6);             %成交量
OpenInterest=data(:,7);       %持仓量
Date_1min = x2mdate(data_1min(:,1),0);
%Date_1min=datenum(data_1min(:,1),'yyyymmddHHMM'); 
High_1min = data_1min(:,3);
Low_1min = data_1min(:,4);
Close_1min = data_1min(:,5);
%% --定义参数（常量）--

%策略参数
Slip=2;                                      %滑点
%BollLength=50;                               %布林线长度
%Offset=1.25;                                 %布林线标准差倍数
%ROCLength=30;                                %ROC的周期数
ShortLen = 10;
LongLen = 20;

%品种参数
MinMove=1;                                    %商品的最小变动量
PriceScale=1;                                 %商品的计数单位
TradingUnits=10;                              %交易单位
Lots=1;                                       %交易手数
MarginRatio=0.07;                             %保证金率
TradingCost=0.0003;                           %交易费用设为成交金额的万分之三
RiskLess=0.035;                               %无风险收益率(计算夏普比率时需要)

%% --定义变量--

%策略变量
%UpperLine=zeros(length(data),1);               %上轨
%LowerLine=zeros(length(data),1);               %下轨
%MidLine=zeros(length(data),1);                 %中间线
%Std=zeros(length(data),1);                     %标准差序列
%RocValue=zeros(length(data),1);                %ROC值


%交易记录变量
MyEntryPrice=zeros(length(data_1min),1);            %买卖价格
MarketPosition=0;                              %仓位状态，-1表示持有空头，0表示无持仓，1表示持有多头
pos=zeros(length(data_1min),1);                     %记录仓位情况，-1表示持有空头，0表示无持仓，1表示持有多头
Type=zeros(length(data_1min),1);                    %买卖类型，1标示多头，-1标示空头
OpenPosPrice=zeros(length(data_1min),1);            %记录建仓价格
ClosePosPrice=zeros(length(data_1min),1);           %记录平仓价格
OpenPosNum=0;                                  %建仓价格序号
ClosePosNum=0;                                 %平仓价格序号
OpenDate=zeros(length(data_1min),1);            %建仓时间
CloseDate=zeros(length(data_1min),1);           %平仓时间
NetMargin=zeros(length(data_1min),1);               %净利
CumNetMargin=zeros(length(data_1min),1);            %累计净利
RateOfReturn=zeros(length(data_1min),1);            %收益率
CumRateOfReturn=zeros(length(data_1min),1);         %累计收益率
CostSeries=zeros(length(data_1min),1);              %记录交易成本
BackRatio=zeros(length(data_1min),1);               %记录回测比例

CloseLowerDate = zeros(length(data_1min),1);

%记录资产变化变量
LongMargin=zeros(length(data_1min),1);              %多头保证金
ShortMargin=zeros(length(data_1min),1);             %空头保证金
Cash=repmat(1e4,length(data_1min),1);               %可用资金,初始资金为10W
DynamicEquity=repmat(1e4,length(data_1min),1);      %动态权益,初始资金为10W
StaticEquity=repmat(1e4,length(data_1min),1);       %静态权益,初始资金为10W

UpLineAll = zeros(length(data),1);
DownLineAll = zeros(length(data),1);
%% --计算布林带和ROC--
%[UpperLine MidLine LowerLine]=BOLL(Close,BollLength,Offset,0);
%RocValue=ROC(Close,ROCLength);

[MAShort, MALong] = movavg(Close, ShortLen, LongLen);
MAShort(1:ShortLen-1) = Close(1:ShortLen-1);
MALong(1:LongLen-1) = Close(1:LongLen-1);

CurrentMinBarIndex = 818;

QuitPrice = 0;

%% --策略仿真--

for i=LongLen+1:length(data)
    HH20 = max(High(i-LongLen:i-1));
    HH10 = max(High(i-LongLen+10:i-1));
    LL20 = max(Low(i-LongLen:i-1));
    LL10 = max(Low(i-LongLen+10:i-1));
    ATRValue = ATR(High(i-LongLen:i-1),Low(i-LongLen:i-1),Close(i-LongLen:i-1),LongLen,0);

    curDay = data(i);
    curMinBarDay = data_1min(CurrentMinBarIndex);     
    
    isSameDay = 0;
    
    if (curDay - floor(curMinBarDay + 0.125)) >=0
        isSameDay = 1;
    end
    
    while (isSameDay ==1) && (CurrentMinBarIndex~=length(data_1min)) 
        if MarketPosition==0
            LongMargin(CurrentMinBarIndex)=0;                            %多头保证金
            ShortMargin(CurrentMinBarIndex)=0;                           %空头保证金
            StaticEquity(CurrentMinBarIndex)=StaticEquity(CurrentMinBarIndex-1);          %静态权益
            DynamicEquity(CurrentMinBarIndex)=StaticEquity(CurrentMinBarIndex);           %动态权益
            Cash(CurrentMinBarIndex)=DynamicEquity(CurrentMinBarIndex);                   %可用资金
        end
        if MarketPosition==1
            LongMargin(CurrentMinBarIndex)=Close_1min(CurrentMinBarIndex)*Lots*TradingUnits*MarginRatio;
            StaticEquity(CurrentMinBarIndex)=StaticEquity(CurrentMinBarIndex-1);
            EarnPoint = 0;
            for j=1:Lots
                 EarnPoint = EarnPoint + Close_1min(CurrentMinBarIndex) - OpenPosPrice(OpenPosNum - j + 1);
            end
            DynamicEquity(CurrentMinBarIndex)=StaticEquity(CurrentMinBarIndex)+EarnPoint*TradingUnits;
            Cash(CurrentMinBarIndex)=DynamicEquity(CurrentMinBarIndex)-LongMargin(CurrentMinBarIndex);
        end
        if MarketPosition==-1
            ShortMargin(CurrentMinBarIndex)=Close_1min(CurrentMinBarIndex)*Lots*TradingUnits*MarginRatio;
            StaticEquity(CurrentMinBarIndex)=StaticEquity(CurrentMinBarIndex-1);
            EarnPoint = 0;
            for j=1:Lots
                 EarnPoint = EarnPoint + OpenPosPrice(OpenPosNum - j + 1)-Close_1min(CurrentMinBarIndex);
            end
            DynamicEquity(CurrentMinBarIndex)=StaticEquity(CurrentMinBarIndex)+EarnPoint*TradingUnits;
            Cash(CurrentMinBarIndex)=DynamicEquity(CurrentMinBarIndex)-ShortMargin(CurrentMinBarIndex);
        end

        if MarketPosition==0 
            if High_1min(CurrentMinBarIndex) > HH20
                %Open Long
                MarketPosition = 1;
                MyEntryPrice(CurrentMinBarIndex)= HH20 + Slip*MinMove*PriceScale;
                if Open(CurrentMinBarIndex)>MyEntryPrice(CurrentMinBarIndex)    %考虑是否跳空
                    MyEntryPrice(CurrentMinBarIndex)=Open(CurrentMinBarIndex)+Slip*MinMove*PriceScale;
                end
                OpenPosNum=OpenPosNum+1;
                OpenPosPrice(OpenPosNum)=MyEntryPrice(CurrentMinBarIndex);%记录开仓价格
                OpenDate(OpenPosNum)=Date_1min(CurrentMinBarIndex);%记录开仓时间
                Type(OpenPosNum)=1;   %方向为多头
                QuitPrice = OpenPosPrice(OpenPosNum) - 2*ATRValue;
                Lots = 1;
                StaticEquity(CurrentMinBarIndex)=StaticEquity(CurrentMinBarIndex-1);
                DynamicEquity(CurrentMinBarIndex)=StaticEquity(CurrentMinBarIndex)+(Close_1min(CurrentMinBarIndex)-OpenPosPrice(OpenPosNum))*TradingUnits*Lots;
            elseif Low_1min(CurrentMinBarIndex) < LL20
                %Open Short
                MarketPosition = -1;
                MyEntryPrice(CurrentMinBarIndex)= LL20 - Slip*MinMove*PriceScale;
                if Open(CurrentMinBarIndex)< MyEntryPrice(CurrentMinBarIndex)    %考虑是否跳空
                    MyEntryPrice(CurrentMinBarIndex)=Open(CurrentMinBarIndex) - Slip*MinMove*PriceScale;
                end
                OpenPosNum=OpenPosNum+1;
                OpenPosPrice(OpenPosNum)=MyEntryPrice(CurrentMinBarIndex);%记录开仓价格
                OpenDate(OpenPosNum)=Date_1min(CurrentMinBarIndex);%记录开仓时间
                QuitPrice = OpenPosPrice(OpenPosNum) + 2*ATRValue;
                Type(OpenPosNum)=-1;   %方向为空头
                Lots = 1;
                StaticEquity(CurrentMinBarIndex)=StaticEquity(CurrentMinBarIndex-1);
                EarnPoint = 0;
                DynamicEquity(CurrentMinBarIndex)=StaticEquity(CurrentMinBarIndex)+(OpenPosPrice(OpenPosNum)-Close_1min(CurrentMinBarIndex))*TradingUnits*Lots;
            end
        elseif MarketPosition==-1
            if  Lots < 4 && Low_1min(CurrentMinBarIndex) < OpenPosPrice(OpenPosNum) - ATRValue*0.5
                MyEntryPrice(CurrentMinBarIndex) = OpenPosPrice(OpenPosNum) - ATRValue*0.5  - Slip*MinMove*PriceScale; 
                if Open(CurrentMinBarIndex)<MyEntryPrice(CurrentMinBarIndex)    %考虑是否跳空
                    MyEntryPrice(CurrentMinBarIndex)=Open(CurrentMinBarIndex) - Slip*MinMove*PriceScale;
                end
                OpenPosNum=OpenPosNum+1;
                OpenPosPrice(OpenPosNum)=MyEntryPrice(CurrentMinBarIndex);%记录开仓价格
                OpenDate(OpenPosNum)=Date_1min(CurrentMinBarIndex);%记录开仓时间
                Type(OpenPosNum)=-1;   %方向为多头
                Lots = Lots + 1;
                StaticEquity(CurrentMinBarIndex)=StaticEquity(CurrentMinBarIndex-1);
                
                EarnPoint = 0;
                for j=1:Lots
                    EarnPoint = EarnPoint + OpenPosPrice(OpenPosNum - j + 1)-Close_1min(CurrentMinBarIndex);
                end
                DynamicEquity(CurrentMinBarIndex)=StaticEquity(CurrentMinBarIndex)+EarnPoint*TradingUnits;
                QuitPrice = QuitPrice - 0.5*ATRValue;
            end
              
            if Low_1min(CurrentMinBarIndex)< min(HH10,  QuitPrice)
                MarketPosition=0;
                ShortMargin(CurrentMinBarIndex)=0;     %平多后多头保证金为0了
                ClosePosNum=ClosePosNum+1;
                ClosePosPrice(ClosePosNum)=min(HH10,  QuitPrice) - Slip*MinMove*PriceScale;%记录平仓价格
                if Open(CurrentMinBarIndex)< ClosePosPrice(ClosePosNum)    %考虑是否跳空
                   ClosePosPrice(ClosePosNum)=Open(CurrentMinBarIndex) - Slip*MinMove*PriceScale;
                end
                CloseDate(ClosePosNum)=Date_1min(CurrentMinBarIndex);%记录平仓时间
                
                EarnPoint = 0;
                for j=1:Lots
                    EarnPoint = EarnPoint + OpenPosPrice(OpenPosNum - j + 1) - ClosePosPrice(ClosePosNum);
                end
                
                TotalTradingCost = 0;
                for j=1:Lots
                    TotalTradingCost = TotalTradingCost + OpenPosPrice(OpenPosNum - j + 1)*TradingUnits*TradingCost;
                end
                
                TotalTradingCost = TotalTradingCost + ClosePosPrice(ClosePosNum)*TradingUnits*Lots*TradingCost;
                
                StaticEquity(CurrentMinBarIndex)=StaticEquity(CurrentMinBarIndex-1)+EarnPoint*TradingUnits-TotalTradingCost;%平多仓时的静态权益，算法参考TB
                DynamicEquity(CurrentMinBarIndex)=StaticEquity(CurrentMinBarIndex);%空仓时动态权益和静态权益相等
                Cash(CurrentMinBarIndex)=DynamicEquity(CurrentMinBarIndex); %空仓时可用资金等于动态权益
                
                QuitPrice = 0 ;
                Lots = O;
            end
        elseif MarketPosition==1
            if Lots < 4 && High_1min(CurrentMinBarIndex) > OpenPosPrice(OpenPosNum) + ATRValue*0.5
                
                MyEntryPrice(CurrentMinBarIndex) = OpenPosPrice(OpenPosNum) + ATRValue*0.5 +Slip*MinMove*PriceScale; 
                if Open(CurrentMinBarIndex)>MyEntryPrice(CurrentMinBarIndex)    %考虑是否跳空
                    MyEntryPrice(CurrentMinBarIndex)=Open(CurrentMinBarIndex)+Slip*MinMove*PriceScale;
                end
                OpenPosNum=OpenPosNum+1;
                OpenPosPrice(OpenPosNum)=MyEntryPrice(CurrentMinBarIndex);%记录开仓价格
                OpenDate(OpenPosNum)=Date_1min(CurrentMinBarIndex);%记录开仓时间
                Type(OpenPosNum)=1;   %方向为多头
                Lots = Lots + 1;
                StaticEquity(CurrentMinBarIndex)=StaticEquity(CurrentMinBarIndex-1);
                for j=1:Lots
                	EarnPoint = EarnPoint + Close_1min(CurrentMinBarIndex) - OpenPosPrice(OpenPosNum - j + 1);
                end               
                DynamicEquity(CurrentMinBarIndex)=StaticEquity(CurrentMinBarIndex)+EarnPoint*TradingUnits;
                QuitPrice = QuitPrice + 0.5*ATRValue;
            end
            
            if Low_1min(CurrentMinBarIndex)< max(LL10,  QuitPrice)
                MarketPosition=0;
                LongMargin(CurrentMinBarIndex)=0;     %平多后多头保证金为0了
                ClosePosNum=ClosePosNum+1;
                ClosePosPrice(ClosePosNum)=max(LL10,  QuitPrice)- Slip*MinMove*PriceScale;%记录平仓价格
                if Open(CurrentMinBarIndex)< ClosePosPrice(ClosePosNum)    %考虑是否跳空
                   ClosePosPrice(ClosePosNum)=Open(CurrentMinBarIndex) - Slip*MinMove*PriceScale;
                end
                CloseDate(ClosePosNum)=Date_1min(CurrentMinBarIndex);%记录平仓时间
                
                EarnPoint = 0;
                for j=1:Lots
                    EarnPoint = EarnPoint + ClosePosPrice(ClosePosNum)-OpenPosPrice(OpenPosNum - j + 1);
                end
                
                TotalTradingCost = 0;
                for j=1:Lots
                    TotalTradingCost = TotalTradingCost + OpenPosPrice(OpenPosNum - j + 1)*TradingUnits*TradingCost;
                end
                
                TotalTradingCost = TotalTradingCost + ClosePosPrice(ClosePosNum)*TradingUnits*Lots*TradingCost;
                
                StaticEquity(CurrentMinBarIndex)=StaticEquity(CurrentMinBarIndex-1)+EarnPoint*TradingUnits - TotalTradingCost;%平多仓时的静态权益，算法参考TB
                DynamicEquity(CurrentMinBarIndex)=StaticEquity(CurrentMinBarIndex);%空仓时动态权益和静态权益相等
                Cash(CurrentMinBarIndex)=DynamicEquity(CurrentMinBarIndex); %空仓时可用资金等于动态权益
                QuitPrice = 0 ;
                Lots = O;
            end
        
        end
       

        %如果最后一个Bar有持仓，则以收盘价平掉
        if CurrentMinBarIndex==length(data_1min)
            %平多
            if MarketPosition==1
                MarketPosition=0;
                LongMargin(CurrentMinBarIndex)=0; 
                ClosePosNum=ClosePosNum+1;           
                ClosePosPrice(ClosePosNum)=Close_1min(CurrentMinBarIndex);%记录平仓价格
                CloseDate(ClosePosNum)=Date_1min(CurrentMinBarIndex);%记录平仓时间
                EarnPoint = 0;
                for j=1:Lots
                    EarnPoint = EarnPoint + ClosePosPrice(ClosePosNum)-OpenPosPrice(OpenPosNum - j + 1);
                end
                
                TotalTradingCost = 0;
                for j=1:Lots
                    TotalTradingCost = TotalTradingCost + OpenPosPrice(OpenPosNum - j + 1)*TradingUnits*TradingCost;
                end
                
                TotalTradingCost = TotalTradingCost + ClosePosPrice(ClosePosNum)*TradingUnits*Lots*TradingCost;
                
                StaticEquity(CurrentMinBarIndex)=StaticEquity(CurrentMinBarIndex-1)+EarnPoint*TradingUnits - TotalTradingCost;%平多仓时的静态权益，算法参考TB
                DynamicEquity(CurrentMinBarIndex)=StaticEquity(CurrentMinBarIndex);%空仓时动态权益和静态权益相等
                Cash(CurrentMinBarIndex)=DynamicEquity(CurrentMinBarIndex); %空仓时可用资金等于动态权益
            end
            %平空
            if MarketPosition==-1
                MarketPosition=0;
                ShortMargin(CurrentMinBarIndex)=0;
                ClosePosNum=ClosePosNum+1;
                ClosePosPrice(ClosePosNum)=Close_1min(CurrentMinBarIndex);
                CloseDate(ClosePosNum)=Date_1min(CurrentMinBarIndex);
                EarnPoint = 0;
                for j=1:Lots
                    EarnPoint = EarnPoint + OpenPosPrice(OpenPosNum - j + 1) - ClosePosPrice(ClosePosNum);
                end
                
                TotalTradingCost = 0;
                for j=1:Lots
                    TotalTradingCost = TotalTradingCost + OpenPosPrice(OpenPosNum - j + 1)*TradingUnits*TradingCost;
                end
                
                TotalTradingCost = TotalTradingCost + ClosePosPrice(ClosePosNum)*TradingUnits*Lots*TradingCost;
                
                StaticEquity(CurrentMinBarIndex)=StaticEquity(CurrentMinBarIndex-1)+EarnPoint*TradingUnits-TotalTradingCost;%平多仓时的静态权益，算法参考TB
                DynamicEquity(CurrentMinBarIndex)=StaticEquity(CurrentMinBarIndex);%空仓时动态权益和静态权益相等
                Cash(CurrentMinBarIndex)=DynamicEquity(CurrentMinBarIndex); %空仓时可用资金等于动态权益

            end
            
        end
        pos(CurrentMinBarIndex)=MarketPosition;
        
        if CurrentMinBarIndex~=length(data_1min)
            CurrentMinBarIndex = CurrentMinBarIndex+1;
            curMinBarDay = data_1min(CurrentMinBarIndex);  
            if (curDay - floor(curMinBarDay + 0.125)) >=0
                isSameDay = 1;
            else
                isSameDay = 0;
            end
        end
    end
    
end

%% -绩效计算--

RecLength=ClosePosNum;%记录交易长度

%净利润和收益率
for i=1:RecLength

    %交易成本(建仓+平仓)
    CostSeries(i)=OpenPosPrice(i)*TradingUnits*Lots*TradingCost+ClosePosPrice(i)*TradingUnits*Lots*TradingCost;
    
    %净利润
    %多头建仓时
    if Type(i)==1
        NetMargin(i)=(ClosePosPrice(i)-OpenPosPrice(i))*TradingUnits*Lots-CostSeries(i);
    end
    %空头建仓时
    if Type(i)==-1
        NetMargin(i)=(OpenPosPrice(i)-ClosePosPrice(i))*TradingUnits*Lots-CostSeries(i);
    end
    %收益率
    RateOfReturn(i)=NetMargin(i)/(OpenPosPrice(i)*TradingUnits*Lots*MarginRatio);
end

%累计净利
CumNetMargin=cumsum(NetMargin);

%累计收益率
CumRateOfReturn=cumsum(RateOfReturn);

%回撤比例
for i=1:length(data_1min)
    c=max(DynamicEquity(1:i));
    if c==DynamicEquity(i)
        BackRatio(i)=0;
    else
        BackRatio(i)=(DynamicEquity(i)-c)/c;
    end
end

%日收益率
Daily=Date_1min(hour(Date_1min)==9  & minute(Date_1min)==0 & second(Date_1min)==0);
DailyEquity=DynamicEquity(hour(Date_1min)==9  & minute(Date_1min)==0 & second(Date_1min)==0);
DailyRet=tick2ret(DailyEquity);

%周收益率
WeeklyNum=weeknum(Daily);    %weeknum返回是一年的第几周
Weekly=[Daily((WeeklyNum(1:end-1)-WeeklyNum(2:end))~=0);Daily(end)];
WeeklyEquity=[DailyEquity((WeeklyNum(1:end-1)-WeeklyNum(2:end))~=0);DailyEquity(end)];
WeeklyRet=tick2ret(WeeklyEquity);

%月收益率
MonthNum=month(Daily);
Monthly=[Daily((MonthNum(1:end-1)-MonthNum(2:end))~=0);Daily(end)];
MonthlyEquity=[DailyEquity((MonthNum(1:end-1)-MonthNum(2:end))~=0);DailyEquity(end)];
MonthlyRet=tick2ret(MonthlyEquity);

%年收益率
YearNum=year(Daily);
Yearly=[Daily((YearNum(1:end-1)-YearNum(2:end))~=0);Daily(end)];
YearlyEquity=[DailyEquity((YearNum(1:end-1)-YearNum(2:end))~=0);DailyEquity(end)];
YearlyRet=tick2ret(YearlyEquity);

%% 自动创建测试报告(输出到excel)
%% 输出交易汇总
Lots = 1;
TradeSum = cell(25,7);

RowNum = 1;
ColNum = 1;
TradeSum{RowNum,1} = '统计指标';
TradeSum{RowNum,2} = '全部交易';
TradeSum{RowNum,3} = '多头';
TradeSum{RowNum,4} = '空头';

%净利润
ProfitTotal=sum(NetMargin);
ProfitLong=sum(NetMargin(Type==1));
ProfitShort=sum(NetMargin(Type==-1));

RowNum = 2;
ColNum = 1;
TradeSum{RowNum,1} = '净利润';
TradeSum{RowNum,2} = ProfitTotal;
TradeSum{RowNum,3} = ProfitLong;
TradeSum{RowNum,4} = ProfitShort;

%总盈利
WinTotal=sum(NetMargin(NetMargin>0));
ans=NetMargin(Type==1);
WinLong=sum(ans(ans>0));
ans=NetMargin(Type==-1);
WinShort=sum(ans(ans>0));

RowNum = 3;
ColNum = 1;
TradeSum{RowNum,1} = '总盈利';
TradeSum{RowNum,2} = WinTotal;
TradeSum{RowNum,3} = WinLong;
TradeSum{RowNum,4} = WinShort;

%总亏损
LoseTotal=sum(NetMargin(NetMargin<0));
ans=NetMargin(Type==1);
LoseLong=sum(ans(ans<0));
ans=NetMargin(Type==-1);
LoseShort=sum(ans(ans<0));

RowNum = 4;
ColNum = 1;
TradeSum{RowNum,1} = '总亏损';
TradeSum{RowNum,2} = LoseTotal;
TradeSum{RowNum,3} = LoseLong;
TradeSum{RowNum,4} = LoseShort;

%总盈利/总亏损
WinTotalDLoseTotal=abs(WinTotal/LoseTotal);
WinLongDLoseLong=abs(WinLong/LoseLong);
WinShortDLoseShort=abs(WinShort/LoseShort);

RowNum = 5;
ColNum = 1;
TradeSum{RowNum,1} = '总盈利/总亏损';
TradeSum{RowNum,2} = WinTotalDLoseTotal;
TradeSum{RowNum,3} = WinLongDLoseLong;
TradeSum{RowNum,4} = WinShortDLoseShort;

%交易手数
LotsTotal=length(Type(Type~=0))*Lots;
LotsLong=length(Type(Type==1))*Lots;
LotsShort=length(Type(Type==-1))*Lots;

RowNum = 7;
ColNum = 1;
TradeSum{RowNum,1} = '交易手数';
TradeSum{RowNum,2} = LotsTotal;
TradeSum{RowNum,3} = LotsLong;
TradeSum{RowNum,4} = LotsShort;

%盈利手数
LotsWinTotal=length(NetMargin(NetMargin>0))*Lots;
ans=NetMargin(Type==1);
LotsWinLong=length(ans(ans>0))*Lots;
ans=NetMargin(Type==-1);
LotsWinShort=length(ans(ans>0))*Lots;

RowNum = 8;
ColNum = 1;
TradeSum{RowNum,1} = '盈利手数';
TradeSum{RowNum,2} = LotsWinTotal;
TradeSum{RowNum,3} = LotsWinLong;
TradeSum{RowNum,4} = LotsWinShort;

%亏损手数
LotsLoseTotal=length(NetMargin(NetMargin<0))*Lots;
ans=NetMargin(Type==1);
LotsLoseLong=length(ans(ans<0))*Lots;
ans=NetMargin(Type==-1);
LotsLoseShort=length(ans(ans<0))*Lots;

RowNum = 9;
ColNum = 1;
TradeSum{RowNum,1} = '亏损手数';
TradeSum{RowNum,2} = LotsLoseTotal;
TradeSum{RowNum,3} = LotsLoseLong;
TradeSum{RowNum,4} = LotsLoseShort;

%持平手数
ans=NetMargin(Type==1);
LotsDrawLong=length(ans(ans==0))*Lots;
ans=NetMargin(Type==-1);
LotsDrawShort=length(ans(ans==0))*Lots;
LotsDrawTotal=LotsDrawLong+LotsDrawShort;

RowNum = 10;
ColNum = 1;
TradeSum{RowNum,1} = '持平手数';
TradeSum{RowNum,2} = LotsDrawTotal;
TradeSum{RowNum,3} = LotsDrawLong;
TradeSum{RowNum,4} = LotsDrawShort;

%盈利比率
LotsWinTotalDLotsTotal=LotsWinTotal/LotsTotal;
LotsWinLongDLotsLong=LotsWinLong/LotsLong;
LotsWinShortDLotsShort=LotsWinShort/LotsShort;

RowNum = 11;
ColNum = 1;
TradeSum{RowNum,1} = '盈利比率';
TradeSum{RowNum,2} = LotsWinTotalDLotsTotal;
TradeSum{RowNum,3} = LotsWinLongDLotsLong;
TradeSum{RowNum,4} = LotsWinShortDLotsShort;

%平均利润
RowNum = 13;
ColNum = 1;
TradeSum{RowNum,1} = '平均利润(净利润/交易手数)';
TradeSum{RowNum,2} = ProfitTotal/LotsTotal;
TradeSum{RowNum,3} = ProfitLong/LotsLong;
TradeSum{RowNum,4} = ProfitShort/LotsShort;

%平均盈利
RowNum = 14;
ColNum = 1;
TradeSum{RowNum,1} = '平均盈利(总盈利金额/盈利交易手数)';
TradeSum{RowNum,2} = WinTotal/LotsWinTotal;
TradeSum{RowNum,3} = WinLong/LotsWinLong;
TradeSum{RowNum,4} = WinShort/LotsWinShort;

%平均亏损
RowNum = 15;
ColNum = 1;
TradeSum{RowNum,1} = '平均亏损(总亏损金额/亏损交易手数)';
TradeSum{RowNum,2} = LoseTotal/LotsLoseTotal;
TradeSum{RowNum,3} = LoseLong/LotsLoseLong;
TradeSum{RowNum,4} = LoseShort/LotsLoseShort;

%平均盈利/平均亏损
RowNum = 16;
ColNum = 1;
TradeSum{RowNum,1} = '平均盈利/平均亏损';
TradeSum{RowNum,2} = abs((WinTotal/LotsWinTotal)/(LoseTotal/LotsLoseTotal));
TradeSum{RowNum,3} = abs((WinLong/LotsWinLong)/(LoseLong/LotsLoseLong));
TradeSum{RowNum,4} = abs((WinShort/LotsWinShort)/(LoseShort/LotsLoseShort));

%最大盈利
MaxWinTotal=max(NetMargin(NetMargin>0));
ans=NetMargin(Type==1);
MaxWinLong=max(ans(ans>0));
ans=NetMargin(Type==-1);
MaxWinShort=max(ans(ans>0));
RowNum = 18;
ColNum = 1;
TradeSum{RowNum,1} = '最大盈利';
TradeSum{RowNum,2} = MaxWinTotal;
TradeSum{RowNum,3} = MaxWinLong;
TradeSum{RowNum,4} = MaxWinShort;

%最大亏损
MaxLoseTotal=min(NetMargin(NetMargin<0));
ans=NetMargin(Type==1);
MaxLoseLong=min(ans(ans<0));
ans=NetMargin(Type==-1);
MaxLoseShort=min(ans(ans<0));
RowNum = 19;
ColNum = 1;
TradeSum{RowNum,1} = '最大亏损';
TradeSum{RowNum,2} = MaxLoseTotal;
TradeSum{RowNum,3} = MaxLoseLong;
TradeSum{RowNum,4} = MaxLoseShort;

%最大盈利/总盈利
RowNum = 20;
ColNum = 1;
TradeSum{RowNum,1} = '最大盈利/总盈利';
TradeSum{RowNum,2} = MaxWinTotal/WinTotal;
TradeSum{RowNum,3} = MaxWinLong/WinLong;
TradeSum{RowNum,4} = MaxWinShort/WinShort;

%最大亏损/总亏损
RowNum = 21;
ColNum = 1;
TradeSum{RowNum,1} = '最大亏损/总亏损';
TradeSum{RowNum,2} = MaxLoseTotal/LoseTotal;
TradeSum{RowNum,3} = MaxLoseLong/LoseLong;
TradeSum{RowNum,4} = MaxLoseShort/LoseShort;

%净利润/最大亏损
RowNum = 22;
ColNum = 1;
TradeSum{RowNum,1} = '净利润/最大亏损';
TradeSum{RowNum,2} = ProfitTotal/MaxLoseTotal;
TradeSum{RowNum,3} = ProfitLong/MaxLoseLong;
TradeSum{RowNum,4} = ProfitShort/MaxLoseShort;

%最大使用资金
RowNum = 24;
ColNum = 1;
TradeSum{RowNum,1} = '最大使用资金';
TradeSum{RowNum,2} = max(max(LongMargin),max(ShortMargin));
TradeSum{RowNum,3} = max(LongMargin);
TradeSum{RowNum,4} = max(ShortMargin);

%交易成本合计
CostTotal=sum(CostSeries);
ans=CostSeries(Type==1);
CostLong=sum(ans);
ans=CostSeries(Type==-1);
CostShort=sum(ans);

RowNum = 25;
ColNum = 1;
TradeSum{RowNum,1} = '交易成本合计';
TradeSum{RowNum,2} = CostTotal;
TradeSum{RowNum,3} = CostLong;
TradeSum{RowNum,4} = CostShort;

%测试时间范围
RowNum = 2;
ColNum = 6;
TradeSum{RowNum,6} = '测试时间范围';
TradeSum{RowNum,7} = ['[',datestr(Date(1),'yyyy-mm-dd HH:MM:SS'),']'];
TradeSum{RowNum,8} = '--';
TradeSum{RowNum,9} = ['[',datestr(Date(end),'yyyy-mm-dd HH:MM:SS'),']'];

%总交易时间
RowNum = 3;
ColNum = 1;
TradeSum{RowNum,6} = '测试天数';
TradeSum{RowNum,7} = round(Date(end)-Date(1));

%持仓时间比例
RowNum = 4;
ColNum = 1;
TradeSum{RowNum,6} = '持仓时间比例';
TradeSum{RowNum,7} = length(pos(pos~=0))/length(data);

%持仓时间
HoldingDays=round(round(Date(end)-Date(1))*(length(pos(pos~=0))/length(data)));%持仓时间
RowNum = 5;
ColNum = 1;
TradeSum{RowNum,6} = '持仓时间(天)';
TradeSum{RowNum,7} = HoldingDays;

%收益率
RowNum = 7;
ColNum = 1;
TradeSum{RowNum,6} = '收益率(%)';
TradeSum{RowNum,7} = (DynamicEquity(end)-DynamicEquity(1))/DynamicEquity(1)*100;

%有效收益率
TrueRatOfRet=(DynamicEquity(end)-DynamicEquity(1))/max(max(LongMargin),max(ShortMargin));
RowNum = 8;
ColNum = 1;
TradeSum{RowNum,6} = '有效收益率(%)';
TradeSum{RowNum,7} = TrueRatOfRet*100;

%年度收益率(按365天算)
RowNum = 9;
ColNum = 1;
TradeSum{RowNum,6} = '年化收益率(按365天算,%)';
TradeSum{RowNum,7} = (1+TrueRatOfRet)^(1/(HoldingDays/365))*100;

%年度收益率(按240天算)
RowNum = 10;
ColNum = 1;
TradeSum{RowNum,6} = '年度收益率(按240天算,%)';
TradeSum{RowNum,7} = (1+TrueRatOfRet)^(1/(HoldingDays/240))*100;

% 年度收益率(按日算)
RowNum = 11;
ColNum = 1;
TradeSum{RowNum,6} = '年度收益率(按日算,%)';
TradeSum{RowNum,7} = mean(DailyRet)*365*100;

%年度收益率(按周算)
RowNum = 12;
ColNum = 1;
TradeSum{RowNum,6} = '年度收益率(按周算,%)';
TradeSum{RowNum,7} = mean(WeeklyRet)*52*100;

%年度收益率(按月算)
RowNum = 13;
ColNum = 1;
TradeSum{RowNum,6} = '年度收益率(按月算,%)';
TradeSum{RowNum,7} = mean(MonthlyRet)*12*100;

%夏普比率(按日算)
RowNum = 14;
ColNum = 1;
TradeSum{RowNum,6} = '夏普比率(按日算,%)';
TradeSum{RowNum,7} = (mean(DailyRet)*365-RiskLess)/(std(DailyRet)*sqrt(365));

%夏普比率(按周算)
RowNum = 15;
ColNum = 1;
TradeSum{RowNum,6} = '夏普比率(按周算,%)';
TradeSum{RowNum,7} = (mean(WeeklyRet)*52-RiskLess)/(std(WeeklyRet)*sqrt(52));

%夏普比率(按月算)
RowNum = 16;
ColNum = 1;
TradeSum{RowNum,6} = '夏普比率(按月算,%)';
TradeSum{RowNum,7} = (mean(MonthlyRet)*12-RiskLess)/(std(MonthlyRet)*sqrt(12));

%最大回撤比例
RowNum = 17;
ColNum = 1;
TradeSum{RowNum,6} = '最大回撤比例(%)';
TradeSum{RowNum,7} = abs(min(BackRatio))*100;

%% 交易汇总整体写入Excel
dirPath = [cd, '\Report\'];
if ~isdir(dirPath)
    mkdir(dirPath);
end

filename = '测试报告.xlsx';
filePath = [cd,'\Report\',filename];
if exist(filePath,'file')
    delete(filePath);
end

sheetName = '交易汇总';
[status,msg] = xlswrite(filePath,TradeSum,sheetName);
%% 输出交易记录

TradeRec = cell(1,1);

RowNum = 1;
ColNum = 1;
TradeRec{1, ColNum} = '#';
Len = length(1:RecLength);
TradeRec(2:Len+1, ColNum) = mat2cell( (1:RecLength)', ones(Len,1) );

RowNum = 1;
ColNum = 2;
TradeRec{1, ColNum} = '类型';
Len = length(1:RecLength);
TradeRec(2:Len+1, ColNum) = mat2cell( Type(1:RecLength), ones(Len,1) );

RowNum = 1;
ColNum = 3;
TradeRec{1, ColNum} = '商品';
Len = length(1:RecLength);
TradeRec(2:Len+1, ColNum) = cellstr(repmat(commodity,RecLength,1));

RowNum = 1;
ColNum = 4;
TradeRec{1, ColNum} = '周期';
Len = length(1:RecLength);
TradeRec(2:Len+1, ColNum) = cellstr(repmat(Freq,RecLength,1));

RowNum = 1;
ColNum = 5;
TradeRec{1, ColNum} = '建仓时间';
Len = length(1:RecLength);
TradeRec(2:Len+1, ColNum) = cellstr(datestr(OpenDate(1:RecLength),'yyyy-mm-dd HH:MM:SS'));

RowNum = 1;
ColNum = 6;
TradeRec{1, ColNum} = '建仓价格';
Len = length(1:RecLength);
TradeRec(2:Len+1, ColNum) = mat2cell( OpenPosPrice(1:RecLength), ones(Len,1) );

RowNum = 1;
ColNum = 7;
TradeRec{1, ColNum} = '平仓时间';
Len = length(1:RecLength);
TradeRec(2:Len+1, ColNum) = cellstr(datestr(CloseDate(1:RecLength),'yyyy-mm-dd HH:MM:SS'));

RowNum = 1;
ColNum = 8;
TradeRec{1, ColNum} = '平仓价格';
Len = length(1:RecLength);
TradeRec(2:Len+1, ColNum) = mat2cell( ClosePosPrice(1:RecLength), ones(Len,1) );

RowNum = 1;
ColNum = 9;
TradeRec{1, ColNum} = '数量';
Len = length(1:RecLength);
TradeRec(2:Len+1, ColNum) = mat2cell( repmat(Lots,RecLength,1), ones(Len,1) );

RowNum = 1;
ColNum = 10;
TradeRec{1, ColNum} = '交易成本';
Len = length(1:RecLength);
TradeRec(2:Len+1, ColNum) = mat2cell( CostSeries(1:RecLength), ones(Len,1) );

RowNum = 1;
ColNum = 11;
TradeRec{1, ColNum} = '净利';
Len = length(1:RecLength);
TradeRec(2:Len+1, ColNum) = mat2cell( NetMargin(1:RecLength), ones(Len,1) );

RowNum = 1;
ColNum = 12;
TradeRec{1, ColNum} = '累计净利';
Len = length(1:RecLength);
TradeRec(2:Len+1, ColNum) = mat2cell( CumNetMargin(1:RecLength), ones(Len,1) );

RowNum = 1;
ColNum = 13;
TradeRec{1, ColNum} = '收益率';
Len = length(1:RecLength);
TradeRec(2:Len+1, ColNum) = mat2cell( RateOfReturn(1:RecLength), ones(Len,1) );

RowNum = 1;
ColNum = 14;
TradeRec{1, ColNum} = '累计收益率';
Len = length(1:RecLength);
TradeRec(2:Len+1, ColNum) = mat2cell( CumRateOfReturn(1:RecLength), ones(Len,1) );

%% 交易记录整体写入Excel
sheetName = '交易记录';
[status,msg] = xlswrite(filePath,TradeRec,sheetName);
%% 输出资产变化

TradeMoney = cell(1,1);
Len = length(1:length(data_1min));

RowNum = 1;
ColNum = 1;
TradeMoney{1, ColNum} = '资产概要';
TradeMoney{2, ColNum} = '起初资产';
TradeMoney{3, ColNum} = StaticEquity(1);

RowNum = 1;
ColNum = 2;
TradeMoney{2, ColNum} = '期末资产';
TradeMoney{3, ColNum} = StaticEquity(end);

RowNum = 1;
ColNum = 3;
TradeMoney{2, ColNum} = '交易盈亏';
TradeMoney{3, ColNum} = sum(NetMargin);

RowNum = 1;
ColNum = 4;
TradeMoney{2, ColNum} = '最大资产';
TradeMoney{3, ColNum} = max(DynamicEquity);

RowNum = 1;
ColNum = 5;
TradeMoney{2, ColNum} = '最小资产';
TradeMoney{3, ColNum} = min(DynamicEquity);

RowNum = 1;
ColNum = 6;
TradeMoney{2, ColNum} = '交易成本合计';
TradeMoney{3, ColNum} = sum(CostSeries);

RowNum = 5;
ColNum = 1;
TradeMoney{5, ColNum} = '资产变化明细';
TradeMoney{6, ColNum} = 'Bar#';
TradeMoney(7:Len+6, ColNum) = mat2cell( (1:length(data_1min))', ones(Len,1) );

RowNum = 5;
ColNum = 2;
TradeMoney{6, ColNum} = '时间';
TradeMoney(7:Len+6, ColNum) = cellstr(datestr(Date_1min,'yyyy-mm-dd HH:MM:SS'));

RowNum = 5;
ColNum = 3;
TradeMoney{6, ColNum} = '多头保证金';
TradeMoney(7:Len+6, ColNum) = mat2cell( LongMargin, ones(Len,1) );

RowNum = 5;
ColNum = 4;
TradeMoney{6, ColNum} = '空头保证金';
TradeMoney(7:Len+6, ColNum) = mat2cell( ShortMargin, ones(Len,1) );

RowNum = 5;
ColNum = 5;
TradeMoney{6, ColNum} = '可用资金';
TradeMoney(7:Len+6, ColNum) = mat2cell( Cash, ones(Len,1) );

RowNum = 5;
ColNum = 6;
TradeMoney{6, ColNum} = '动态权益';
TradeMoney(7:Len+6, ColNum) = mat2cell( DynamicEquity, ones(Len,1) );

RowNum = 5;
ColNum = 7;
TradeMoney{6, ColNum} = '静态权益';
TradeMoney(7:Len+6, ColNum) = mat2cell( StaticEquity, ones(Len,1) );

%% 资产变化整体写入Excel
sheetName = '资产变化';
[status,msg] = xlswrite(filePath,TradeMoney,sheetName);
%% --图表分析--

dirPath = [cd, '\Report\'];

%画出布林带(部分)
%scrsz = get(0,'ScreenSize');
%figure('Position',[scrsz(3)*1/4 scrsz(4)*1/6 scrsz(3)*4/5 scrsz(4)]*3/4);
%candle(High(end-150:end),Low(end-150:end),Open(end-150:end),Close(end-150:end),'r');
%hold on;
%plot([MidLine(end-150:end)],'k');
%plot([UpperLine(end-150:end)],'g');
%plot([LowerLine(end-150:end)],'g');
%title('布林带(仅部分)');
%saveas(gcf,[dirPath, '1布林带(仅部分).png']);
% close all;

%交易盈亏曲线及累计成本
scrsz = get(0,'ScreenSize');
figure('Position',[scrsz(3)*1/4 scrsz(4)*1/6 scrsz(3)*4/5 scrsz(4)]*3/4);
subplot(2,1,1);
area(1:RecLength,CumNetMargin(1:RecLength),'FaceColor','g');
axis([1 RecLength min(CumNetMargin(1:RecLength)) max(CumNetMargin(1:RecLength))]);
xlabel('交易次数');
ylabel('交易盈亏(元)');
title('交易盈亏曲线');

subplot(2,1,2);
plot(CumNetMargin(1:RecLength),'r','LineWidth',2);
hold on;
plot(cumsum(CostSeries(1:RecLength)),'b','LineWidth',2);
axis([1 RecLength min(CumNetMargin(1:RecLength)) max(CumNetMargin(1:RecLength))]);
xlabel('交易次数');
ylabel('交易盈亏及成本(元)');
legend('交易盈亏','累计成本','Location','NorthWest');
hold off;
saveas(gcf,[dirPath, '2交易盈亏曲线.png']);
% close all;

%交易盈亏分布图
scrsz = get(0,'ScreenSize');
figure('Position',[scrsz(3)*1/4 scrsz(4)*1/6 scrsz(3)*4/5 scrsz(4)]*3/4);
subplot(2,1,1);
ans=NetMargin(1:RecLength);%正收益和负收益用不同的颜色表示
ans(ans<0)=0;
plot(ans,'r.');
hold on;
ans=NetMargin(1:RecLength);
ans(ans>0)=0;
plot(ans,'b.');
xlabel('盈亏(元)');
ylabel('交易次数');
title('交易盈亏分布图');

subplot(2,1,2);
hist(NetMargin(1:RecLength),50);
h = findobj(gca,'Type','patch');
set(h,'FaceColor','r','EdgeColor','w')
xlabel('频率');
ylabel('盈亏分组');
saveas(gcf, [dirPath, '3交易盈亏分布图.png']);
% close all;

%权益曲线
scrsz = get(0,'ScreenSize');
figure('Position',[scrsz(3)*1/4 scrsz(4)*1/6 scrsz(3)*4/5 scrsz(4)]*3/4);
plot(Date_1min,DynamicEquity,'r','LineWidth',2);
hold on;
area(Date_1min,DynamicEquity,'FaceColor','g');
datetick('x',29);
axis([Date_1min(1) Date_1min(end) min(DynamicEquity) max(DynamicEquity)]);
xlabel('时间');
ylabel('动态权益(元)');
title('权益曲线图');
hold off;
saveas(gcf, [dirPath, '4权益曲线图.png']);
% close all;

%仓位及回测比例
scrsz = get(0,'ScreenSize');
figure('Position',[scrsz(3)*1/4 scrsz(4)*1/6 scrsz(3)*4/5 scrsz(4)]*3/4);
subplot(2,1,1);
plot(Date_1min,pos,'g');
datetick('x',29);
axis([Date_1min(1) Date_1min(end) min(pos) max(pos)]);
xlabel('时间');
ylabel('仓位');
title('仓位状态(1-多头 0-不持仓 -1-空头)');

subplot(2,1,2);
plot(Date_1min,BackRatio,'b');
datetick('x',29);
axis([Date_1min(1) Date_1min(end) min(BackRatio) max(BackRatio)]);
xlabel('时间');
ylabel('回撤比例');
title(strcat('回撤比例（初始资金为：',num2str(DynamicEquity(1)),'，开仓比例：',num2str(max(max(LongMargin),max(ShortMargin))/DynamicEquity(1)*100),'%',...
    '，保证金比例：',num2str(MarginRatio*100),'%）'));
saveas(gcf, [dirPath, '5仓位及回测比例.png']);
% close all;

%多空对比
scrsz = get(0,'ScreenSize');
figure('Position',[scrsz(3)*1/4 scrsz(4)*1/6 scrsz(3)*4/5 scrsz(4)]*3/4);
subplot(2,2,1);
pie3([LotsWinLong LotsLoseLong],[1 0],{strcat('多头盈利手数:',num2str(LotsWinLong),'手，','占比:',num2str(LotsWinLong/(LotsWinLong+LotsLoseLong)*100),'%')...
    ,strcat('多头亏损手数:',num2str(LotsLoseLong),'手，','占比:',num2str(LotsLoseLong/(LotsWinLong+LotsLoseLong)*100),'%')});

subplot(2,2,2);
pie3([WinLong abs(LoseLong)],[1 0],{strcat('多头总盈利:',num2str(WinLong),'元，','占比:',num2str(WinLong/(WinLong+abs(LoseLong))*100),'%')...
    ,strcat('多头总亏损:',num2str(abs(LoseLong)),'元，','占比:',num2str(abs(LoseLong)/(WinLong+abs(LoseLong))*100),'%')});

subplot(2,2,3);
pie3([LotsWinShort LotsLoseShort],[1 0],{strcat('空头盈利手数:',num2str(LotsWinShort),'手，','占比:',num2str(LotsWinShort/(LotsWinShort+LotsLoseShort)*100),'%')...
,strcat('空头亏损手数:',num2str(LotsLoseShort),'手，','占比:',num2str(LotsLoseShort/(LotsWinShort+LotsLoseShort)*100),'%')});

subplot(2,2,4);
pie3([WinShort abs(LoseShort)],[1 0],{strcat('空头总盈利:',num2str(WinShort),'元，','占比:',num2str(WinShort/(WinShort+abs(LoseShort))*100),'%')...
    ,strcat('空头总亏损:',num2str(abs(LoseShort)),'元，','占比:',num2str(abs(LoseShort)/(WinShort+abs(LoseShort))*100),'%')});
saveas(gcf, [dirPath, '6多空对比饼图.png']);
% close all;

%% 收益多周期统计
scrsz = get(0,'ScreenSize');
figure('Position',[scrsz(3)*1/4 scrsz(4)*1/6 scrsz(3)*4/5 scrsz(4)]*3/4);
subplot(2,2,1);
bar(Daily(2:end),DailyRet,'r','EdgeColor','r');
datetick('x',29);
axis([min(Daily(2:end)) max(Daily(2:end)) min(DailyRet) max(DailyRet)]);
xlabel('时间');
ylabel('日收益率');

subplot(2,2,2);
bar(Weekly(2:end),WeeklyRet,'r','EdgeColor','r');
datetick('x',29);
axis([min(Weekly(2:end)) max(Weekly(2:end)) min(WeeklyRet) max(WeeklyRet)]);
xlabel('时间');
ylabel('周收益率');

subplot(2,2,3);
bar(Monthly(2:end),MonthlyRet,'r','EdgeColor','r');
datetick('x',28);
axis([min(Monthly(2:end)) max(Monthly(2:end)) min(MonthlyRet) max(MonthlyRet)]);
xlabel('时间');
ylabel('月收益率');

subplot(2,2,4);
bar(Yearly(2:end),YearlyRet,'r','EdgeColor','r');
datetick('x',10);
axis([min(Yearly(2:end)) max(Yearly(2:end)) min(YearlyRet) max(YearlyRet)]);
xlabel('时间');
ylabel('年收益率');
saveas(gcf, [dirPath, '7收益多周期统计.png']);
% close all;