function [UpperLine MiddleLine LowerLine]=BOLL(Price,Length,Width,Type)
%----------------------此函数用来计算BOLL指标(布林线指标)------------------
%----------------------------------编写者--------------------------------
%Lian Xiangbin(连长,785674410@qq.com),DUFE,2014
%----------------------------------参考----------------------------------
%[1]浙商证券.技术指标优化择时：10年30倍收益,2010-12-23
%[2]来自网络.24个基本指标精粹讲解
%[3]姜金胜.指标精萃：经典技术指标精解与妙用.东华大学出版社,2004年01月第1版
%----------------------------------简介----------------------------------
%BOLL指标又叫布林线指标，其英文全称是“Bolinger Bands”，是用该指标的
%创立人约翰·布林 的姓来命名的，是研判价格运动趋势的一种中长期技术分析
%工具。BOLL指标是美国股市分析家约翰·布林根据统计学中的标准差原理设计
%出来的一种非常简单实用的技术分析指标。一般而言，价格的运动总是围绕某
%一价值中枢（如均线、成本线等）在一定的范围内变动，布林线指标指标正是
%在上述条件的基础上，引进了“价格通道”的概念，其认为价格通道的宽窄随
%着价格波动幅度的大小而变化，而且价格通道又具有变异性，它会随着价格的
%变化而自动调整。正是由于它具有灵活性、直观性和趋势性的特点，BOLL指标
%渐渐成为投资者广为应用的市场上热门指标。BOLL 是利用“价格通道”来显
%示价格的各种价位，当价格波动很小，处于盘整时，价格通道就会变窄，这可
%能预示着价格的波动处于暂时的平静期；当价格波动超出狭窄的价格通道的上
%轨时，预示着价格的异常激烈的向上波动即将开始；当价格波动超出狭窄的价
%格通道的下轨时，同样也预示着价格的异常激烈的向下波动将开始。总之，BOLL 
%指标中的价格通道对预测未来行情的走势起着重要的参考作用，它也是布林线指
%标所特有的分析手段 
%----------------------------------基本用法------------------------------
%1)当股价在中轨与上轨之间时为多头市场，当股价在中轨与下轨之间时为空头市场
%2)当股价由下向上穿越下轨（或中轨）时，是买进（或加速买仓信号）
%   当股价由上向下穿越上轨（或中轨）时，是卖出信号
%更多用法，请查看参考
%----------------------------------调用函数------------------------------
%[UpperLine MiddleLine LowerLine]=BOLL(Price,Length,Width,Type)
%----------------------------------参数----------------------------------
%Price-价格序列，常用收盘价
%Length-计算移动平均的长度，常用20
%Width-计算布林线上轨和下轨的宽度，即多少个标准差，常用2
%Type-计算移动平均值的类型，0为简单移动平均，1为指数移动平均，默认为0
%----------------------------------输出----------------------------------
%UpperLine-上轨
%MiddleLine-中轨
%LowerLine-下轨

if nargin==3
    Type=0;
end
MiddleLine=zeros(length(Price),1);
UpperLine=zeros(length(Price),1);
LowerLine=zeros(length(Price),1);
%使用简单移动平均线
if Type==0
    MiddleLine=MA(Price,Length);
    UpperLine(1:Length-1)=MiddleLine(1:Length-1);
    LowerLine(1:Length-1)=MiddleLine(1:Length-1);
    for i=Length:length(Price)
        UpperLine(i)=MiddleLine(i)+Width*std(Price(i-Length+1:i));
        LowerLine(i)=MiddleLine(i)-Width*std(Price(i-Length+1:i));
    end
end
%使用指数移动平均线
if Type==1
    MiddleLine=EMA(Price,Length);
    UpperLine(1:Length-1)=MiddleLine(1:Length-1);
    LowerLine(1:Length-1)=MiddleLine(1:Length-1);
    for i=Length:length(Price)
        StanDev(i)=sqrt(sum((Price(i-Length+1:i)-MiddleLine(i)).^2)/Length);
        UpperLine(i)=MiddleLine(i)+Width*StanDev(i);
        LowerLine(i)=MiddleLine(i)-Width*StanDev(i);       
    end
end
end

