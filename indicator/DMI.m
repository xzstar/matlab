function [PosDI,NegDI,ADX]=DMI(High,Low,Close,N)
%--------------------此程序用来计算DMI指标(趋向指标)-----------------------
%----------------------------------编写者--------------------------------
%Lian Xiangbin(连长,785674410@qq.com),DUFE,2014
%----------------------------------参考----------------------------------
%[1]Elder.以交易为生.机械工业出版社，2010年4月第1版
%[2]来自网络.学会利用关键技术指标
%[3]Wilder.《技术交易系统新概念》
%----------------------------------简介----------------------------------
%趋向指标DMI又称为动向指标，是由美国技术分析大师威尔斯.维尔德(Wells Wilder)所
%创造的，其基本原理是在于寻找证券涨跌过程中，股价藉以创新高或新低的功能，研判多
%空力量，进而寻求买卖双方的均衡点及股价在双方互动下波动的循环过程。
%----------------------------------基本用法------------------------------
%1)当+/-DI 上穿-/+DI 时，意味着，上涨（下跌）倾向强于下跌（上涨）倾向
%一个买/卖信号生成。这时一个高/低DX 代表一个强/弱趋势
%2)当 ADX 数值降低到 20 以下，且显现横盘时，此时股价处于小幅盘整中，当
%ADX 突破 40 并明显上升时，股价上升趋势确立.如果 ADX 在 50 以上反
%转向下，此时，不论股价正在上涨或下跌，都预示行情即将反转。 
%----------------------------------调用函数------------------------------
%[PosDI,NegDI,ADX]=DMI(High,Low,Close,N)
%----------------------------------参数----------------------------------
%High-最高价序列
%Low-最低价序列
%Close-收盘价序列
%N-计算趋向指标和趋向平均线时所考虑的周期
%----------------------------------输出----------------------------------
%PosDI-正趋向指标
%NegDI-负趋向指标
%ADX-趋向平均线

PosDM=zeros(length(High),1);
NegDM=zeros(length(High),1);
TR=zeros(length(High),1);
PosDI=zeros(length(High),1);
NegDI=zeros(length(High),1);
DX=zeros(length(High),1);
ADX=zeros(length(High),1);
for i=N:length(High)
%step1:计算趋向变动值
if High(i)-High(i-1)>0
PosDM(i)=High(i)-High(i-1);
else PosDM(i)=0;
end
if Low(i-1)-Low(i)>0
NegDM(i)=Low(i-1)-Low(i);
else NegDM(i)=0;
end
if PosDM(i)>0 && NegDM(i)>0
    PosDM(i)=(PosDM(i)>NegDM(i))*PosDM(i);
    NegDM(i)=(PosDM(i)<NegDM(i))*NegDM(i);
end
%step2:计算真实波幅
TR(i)=max([abs(High(i)-Low(i)) abs(High(i)-Close(i-1)) abs(Low(i)-Close(i-1))]);
%step3:计算N日线趋向指标(移动平均)
PosDI(i)=sum(PosDM(i-N+1:i))/sum(TR(i-N+1:i))*100;
NegDI(i)=sum(NegDM(i-N+1:i))/sum(TR(i-N+1:i))*100;
%step4:计算趋向平均线
DX(i)=abs((PosDI(i)-NegDI(i)))/(PosDI(i)+NegDI(i))*100;
ADX(i)=2/(N+1)*DX(i)+(1-2/(N+1))*ADX(i-1);%指数移动平均
end
end

