function RVIValue=RVI(Price,stdLength,Length)
%---------------------此函数用来计算RVI指标(相对波动指数)------------------
%----------------------------------编写者--------------------------------
%Lian Xiangbin(连长,785674410@qq.com),DUFE,2014
%----------------------------------参考----------------------------------
%[1]MBA智库百科.RVI词条
%[2]交易开拓者.公式应用RVI算法
%----------------------------------简介----------------------------------
%相对离散指数(Relative Volatility Index，RVI)又称“相对波动性指标”，用于
%测量价格的发散趋势，由著名分析家唐纳德?多西(Donald Dorsey)于1993年提出。
%其原理与相对强弱指标(RSI)类似，但它是以价格的方差而不是简单的升跌来测量
%价格变化的强度。相对离散指数(RVI)主要用作辅助的确认指标，即配合均线系统、
%动量指标或其它趋势指标使用。用于RVI综合了多种不同的因素，通常比其它辅助
%指标要好。
%----------------------------------基本用法------------------------------
%1)当RVI大于50时,可以买入。
%2)当RVI小于50时,可以卖出。
%3)RVI指标一般作为辅助指标使用。
%----------------------------------调用函数------------------------------
%RVIValue=RVI(Price,stdLength.Length)
%----------------------------------参数----------------------------------
%Price-价格序列，常用收盘价
%stdLength-计算标准差时的周期，常用10个Bar
%Length-计算RVI时的周期，常用14个Bar
%----------------------------------输出----------------------------------
%RVIValue-相对波动指数

RVIValue=zeros(length(Price),1);
stdValue=zeros(length(Price),1);
DiffofPrice=zeros(length(Price),1);
DiffofPrice(2:end)=Price(2:end)-Price(1:end-1);
for i=stdLength:length(Price)
    stdValue(i)=std(Price(i-stdLength+1:i));
end
Temp1=stdValue;
Temp1(DiffofPrice<0)=0;
Temp2=stdValue;
Temp2(DiffofPrice>0)=0;
RVIValue(1:Length-1)=50;
for j=Length:length(Price)
    RVIValue(j)=sum(Temp1(j-Length+1:j))/(sum(Temp1(j-Length+1:j))+sum(Temp2(j-Length+1:j)))*100;
end
end

