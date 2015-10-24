function [DIF,DEA,MACDValue]=MACD(Price,FastLength,SlowLength,DEALength)
%-------------------------此函数用来计算MACD指标--------------------------
%----------------------------------编写者--------------------------------
%Lian Xiangbin(连长,785674410@qq.com),DUFE,2014
%----------------------------------参考----------------------------------
%[1]招商证券.基于纯技术指标的多因子选股模型,2014-04-11
%----------------------------------简介----------------------------------
%MACD（Moving Average Convergence Divergence）称为指数平滑异
%同平均线均线，是技术分析领域应用广泛的指标之一，包含了三个参数，
%常用的设置有（12，26，9）。MACD是计算两条不同速度（长期与中期
%）的指数平滑移动平均线（EMA）的差离状况来作为研判行情的基础。DIF
%为12周期均值与26周期均值之差，DEA为DIF的9周期均值，而MACD则为DIF
%与DEA差值的两倍。
%----------------------------------基本用法------------------------------
%1)当DIF和 DEA处于0轴以上时，属于多头市场，否则为空头市场
%2)当 DIF 线自下而上穿越 DEA 线时是买入信号，反之是卖出信号
%----------------------------------调用函数------------------------------
%[DIF,DEA,MACDValue]=MACD(Price,FastLength,SlowLength,DEALength)
%----------------------------------参数----------------------------------
%Price-目标价格序列
%FastLength-计算DIF时的短周期，常用12
%SlowLength-计算DIF时的长周期，常用26
%DEALength-计算DEA时的周期，常用9
%----------------------------------输出----------------------------------
%DIF-差离值（DIF）的计算： DIF = EMA12 - EMA26 
%DEA-DIF的N日指数移动平均
%MACDValue-2*（DIF-DEA）

DIF=zeros(length(Price),1);
DEA=zeros(length(Price),1);
MACDValue=zeros(length(Price),1);
DIF=EMA(Price,FastLength)-EMA(Price,SlowLength);
DEA=EMA(DIF,DEALength);
MACDValue=2*(DIF-DEA);
end

