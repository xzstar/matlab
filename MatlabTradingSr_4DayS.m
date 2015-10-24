function MatlabTradingDemo
% MATLAB开发交易策略范例：一个简单均线交易系统
% by LiYang 2014/05/01 farutliyang@foxmail.com

%% 清空工作空间、命令窗口
clc;clear;
close all;
format compact;
%% 载入测试数据 : 股指连续IF888 2011年全年数据
rb000 =load('sr000_day.csv');
date = rb000(200:300, 1);
IFdata = rb000(200:300, 5);
Opendata = rb000(200:300, 2);
Highdata = rb000(200:300, 3);

%% 选择短期5日均线、长期20日均线
ShortLen = 5;
LongLen = 20;
[MA5, MA20] = movavg(IFdata, ShortLen, LongLen);
MA5(1:ShortLen-1) = IFdata(1:ShortLen-1);
MA20(1:LongLen-1) = IFdata(1:LongLen-1);

Count = 4;


scrsz = get(0,'ScreenSize');
figure('Position',[scrsz(3)*1/4 scrsz(4)*1/6 scrsz(3)*4/5 scrsz(4)]*3/4);
plot(IFdata,'b','LineStyle','-','LineWidth',1.5);
hold on;
plot(MA5,'r','LineStyle','--','LineWidth',1.5);
plot(MA20,'k','LineStyle','-.','LineWidth',1.5);
grid on;
legend('IF888','MA5','MA20','Location','Best');
title(num2str(IFdata(1)),'FontWeight', 'Bold');
hold on;
%% 交易过程仿真

% 仓位 Pos = 1 多头1手; Pos = 0 空仓; Pos = -1 空头一手
Pos = zeros(length(IFdata),1);
% 初始资金
InitialE = 1e4;
% 日收益记录
ReturnD = zeros(length(IFdata),1);
% 股指乘数
scale = 10;%300;


PreviousPos = zeros(Count,1);

lastPrice = 0;
for t = Count+1:length(IFdata)
    
    PreviousPos = Opendata(t-Count:t-1);
    OpenHighest = max(PreviousPos);
    PreviousPos = Highdata(t-Count:t-1);
    HighLowest = min(PreviousPos);
    
    if Pos(t-1) == 0
        if Opendata(t)>OpenHighest
            Pos(t) = 1;
            text(t,OpenHighest,' \leftarrow开多1手','FontSize',8);
            plot(t,OpenHighest,'ro','markersize',8);
            %ReturnD(t) = (IFdata(t)-IFdata(t-1))*scale;
            fprintf(1,'%d 开多1手 %d\n' ,t,Opendata(t));
            lastPrice = Opendata(t);
            continue;
        end
        
        if Highdata(t)<HighLowest
            Pos(t) = -1;
            text(t,HighLowest,' \leftarrow开空1手','FontSize',8);
            plot(t,HighLowest,'rd','markersize',8);
            %ReturnD(t) = (IFdata(t-1)-IFdata(t))*scale;
            fprintf(1,'%d 开空1手 %\n' ,t,Highdata(t));
            lastPrice = Highdata(t);
            continue;
        end
    end
    
    if Pos(t-1) == 1
        if Highdata(t)<HighLowest
            Pos(t) = -1;
            ReturnD(t) = (IFdata(t-1)-IFdata(t))*scale;
            text(t,Highdata(t),' \leftarrow平多开空1手','FontSize',8);
            plot(t,Highdata(t),'rd','markersize',8);
            %fprintf(1,'%d 平多开空 %d %d\n' ,t,Lowest,Lowest - lastPrice);
            fprintf(1,'%d\n' ,Highdata(t) - lastPrice);
            lastPrice = Highdata(t);
            continue;
        end
    end
    
     if Pos(t-1) == -1
        if Opendata(t)>OpenHighest
            Pos(t) = 1;
            ReturnD(t) = (IFdata(t)-IFdata(t-1))*scale;
            text(t,Opendata(t),' \leftarrow平空开多1手','FontSize',8);
            plot(t,Opendata(t),'ro','markersize',8);    
            %fprintf(1,'%d 平空开多 %d %d\n' ,t,Highest,lastPrice - Highest);
            fprintf(1,'%d\n' ,lastPrice - Opendata(t));
            lastPrice = Opendata(t);

            continue;
        end
    end
    
%     % 买入信号 : 5日均线上穿20日均线
%     %SignalBuy = MA5(t)>MA5(t-1) && MA5(t)>MA20(t) && MA5(t-1)>MA20(t-1) && MA5(t-2)<=MA20(t-2);
%     %SignalBuy = IFdata(t) > MA20(t);
%     SignalBuy = Highdata
%     % 卖出信号 : 5日均线下破20日均线
%     %SignalSell = MA5(t)<MA5(t-1) && MA5(t)<MA20(t) && MA5(t-1)<MA20(t-1) && MA5(t-2)>=MA20(t-2);
%     %SignalSell = MA20(t) > IFdata(t);
%     % 买入条件
%     if SignalBuy == 1
%         % 空仓开多头1手
%         if Pos(t-1) == 0
%             Pos(t) = 1;
%             text(t,IFdata(t),' \leftarrow开多1手','FontSize',8);
%             plot(t,IFdata(t),'ro','markersize',8);
%             continue;
%         end
%         % 平空头开多头1手
%         if Pos(t-1) == -1
%             Pos(t) = 1;
%             ReturnD(t) = (IFdata(t-1)-IFdata(t))*scale;
%             text(t,IFdata(t),' \leftarrow平空开多1手','FontSize',8);
%             plot(t,IFdata(t),'ro','markersize',8);           
%             continue;
%         end
%     end
%     
%     % 卖出条件
%     if SignalSell == 1
%         % 空仓开空头1手
%         if Pos(t-1) == 0
%             Pos(t) = -1;
%             text(t,IFdata(t),' \leftarrow开空1手','FontSize',8);
%             plot(t,IFdata(t),'rd','markersize',8);
%             continue;
%         end
%         % 平多头开空头1手
%         if Pos(t-1) == 1
%             Pos(t) = -1;
%             ReturnD(t) = (IFdata(t)-IFdata(t-1))*scale;
%             text(t,IFdata(t),' \leftarrow平多开空1手','FontSize',8);
%             plot(t,IFdata(t),'rd','markersize',8);
%             continue;
%         end
%     end
    
    % 每日盈亏计算
    if Pos(t-1) == 1
        Pos(t) = 1;
        ReturnD(t) = (IFdata(t)-IFdata(t-1))*scale;
    end
    if Pos(t-1) == -1
        Pos(t) = -1;
        ReturnD(t) = (IFdata(t-1)-IFdata(t))*scale;
    end
    if Pos(t-1) == 0
        Pos(t) = 0;
        ReturnD(t) = 0;
    end    
    
    % 最后一个交易日如果还有持仓，进行平仓
    if t == length(IFdata) && Pos(t-1) ~= 0
        if Pos(t-1) == 1
            Pos(t) = 0;
            ReturnD(t) = (IFdata(t)-IFdata(t-1))*scale;
            text(t,IFdata(t),' \leftarrow平多1手','FontSize',8);
            plot(t,IFdata(t),'rd','markersize',8);
        end
        if Pos(t-1) == -1
            Pos(t) = 0;
            ReturnD(t) = (IFdata(t-1)-IFdata(t))*scale;
            text(t,IFdata(t),' \leftarrow平空1手','FontSize',8);
            plot(t,IFdata(t),'ro','markersize',8);
        end
    end
    
end
%% 累计收益
ReturnCum = cumsum(ReturnD);
ReturnCum = ReturnCum + InitialE;
%% 计算最大回撤
MaxDrawD = zeros(length(IFdata),1);
for t = LongLen:length(IFdata)
    C = max( ReturnCum(1:t) );
    if C == ReturnCum(t)
        MaxDrawD(t) = 0;
    else
        MaxDrawD(t) = (ReturnCum(t)-C)/C;
    end
end
MaxDrawD = abs(MaxDrawD);
%% 图形展示
scrsz = get(0,'ScreenSize');
figure('Position',[scrsz(3)*1/4 scrsz(4)*1/6 scrsz(3)*4/5 scrsz(4)]*3/4);
subplot(3,1,1);
plot(ReturnCum);
grid on;
axis tight;
title('收益曲线','FontWeight', 'Bold');

subplot(3,1,2);
plot(Pos,'LineWidth',1.8);
grid on;
axis tight;
title('仓位','FontWeight', 'Bold');

subplot(3,1,3);
plot(MaxDrawD);
grid on;
axis tight;
title(['最大回撤（初始资金',num2str(InitialE/1e4),'万）'],'FontWeight', 'Bold');
