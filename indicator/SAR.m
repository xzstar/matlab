function [SARofCurBar,SARofNextBar,Position,Transition]=SAR(a,b)
%--------------------此程序用来计算SAR指标(抛物线指标)---------------------
%----------------------------------编写者--------------------------------
%Lian Xiangbin(连长,785674410@qq.com),DUFE,2014
%----------------------------------参考----------------------------------
%[1]Wilder.《技术交易系统新概念》
%[2]姜金胜.指标精萃：经典技术指标精解与妙用.东华大学出版社,2004年01月第1版
%[3]交易开拓者.parabolicSAR函数的算法
%[4]浙商证券.技术指标优化择时：10年30倍收益,2010-12-23
%----------------------------------简介----------------------------------
%SAR (Stop and Reveres)指标又叫抛物线指标或停损指标，是由美国技术分析大
%师威尔斯-威尔德（Wells Wilder）所创造的。SAR之所以称为停损指标，是因为它
%是基于以下的停损策略而设计的。该停损策略是在买卖某个股票之前，先要设定一
%个止损价位，以减少投资风险。而这个止损价位也不是一成不变的，它随着股价的
%波动止损位而不断调整。这样，既可以有效地控制住潜在风险，又不会错失获利的
%机会。SAR的第二层含义是“Reverse”，即反转、反向操作之意，当价格达到止损
%价位时，投资者不仅要对前期买入的股票进行平仓，而且要在平仓的同时进行反向
%做空操作，以谋求收益的最大化。
%----------------------------------基本用法------------------------------
%1)当价格从SAR曲线下方开始向上突破SAR曲线时，为买入信号
%2)当价格从SAR曲线上方开始向下跌破SAR曲线时，为卖出信号
%----------------------------------调用函数------------------------------
%[SARofCurBar,SARofNextBar,Position,Transition]=SAR(a,b)
%----------------------------------参数----------------------------------
%a-初始加速因子
%b-加速因子的最大值
%----------------------------------输出----------------------------------
%SARofCurBar-当前Bar的停损值
%SARofNextBar-下一个Bar的停损值
%Position-输出建议的持仓状态，1-多头，-1-空头
%Transition-当前Bar的状态是否发生反转，1或-1为反转，0为保持不变

AfStep=a;%初始加速因子，也是步长
AfLimit=b;%加速因子的最大值
%定义变量
L=length(DateTime);
Af=zeros(L,1);%加速因子
SARofCurBar=zeros(L,1);%当前Bar的SAR值
SARofNextBar=zeros(L,1);%下一个Bar的SAR值
Position=zeros(L,1);%建议的持仓状态，1-多头，-1空头
Transition=0;%输出是否发生反转，1表示反转为多头，-1表示反转为空头，0为保持不变
HighestPoint=zeros(L,1);%反转发生后的最高点
LowestPoint=zeros(L,1);%反转发生后的最低点
%具体计算
for i=1:L
    %第一根Bar首次进入，假设为多头
    if i==1
        Position(i)=1;
        Transition=1;
        Af(i)=AfStep;
        HighestPoint(i)=High(i);
        LowestPoint(i)=Low(i);
        SARofCurBar(i)=LowestPoint(i);
        SARofNextBar(i)=SARofCurBar(i)+Af(i)*(HighestPoint(i)-SARofCurBar(i));
        if SARofNextBar(i)>Low(i)
            SARofNextBar(i)=Low(i);
        end       
    end
    %其他Bar
    if i>1
        Transition=0;
        %判断反转发生后的最高点和最低点
        HighestPoint(i)=max(High(i),HighestPoint(i-1));
        LowestPoint(i)=min(Low(i),LowestPoint(i-1));
        %多头情形下
        if Position(i-1)==1
            %如果满足反转条件
            if Low(i)<=SARofNextBar(i-1)
                Position(i)=-1;
                Transition=-1;
                SARofCurBar(i)=HighestPoint(i);
                HighestPoint(i)=High(i);
                LowestPoint(i)=Low(i);
                Af(i)=AfStep;
                SARofNextBar(i)=SARofCurBar(i)+Af(i)*(LowestPoint(i)-SARofCurBar(i));
                SARofNextBar(i)=max([SARofNextBar(i) High(i) High(i-1)]);
            %如果不满足反转条件
            else
                Position(i)=Position(i-1);
                SARofCurBar(i)=SARofNextBar(i-1);
                if HighestPoint(i)>HighestPoint(i-1) && Af(i-1)<AfLimit
                    if Af(i-1)+AfStep>AfLimit
                        Af(i)=AfLimit;
                    else
                        Af(i)=Af(i-1)+AfStep;
                    end
                else
                    Af(i)=Af(i-1);
                end
               SARofNextBar(i)=SARofCurBar(i)+Af(i)*(HighestPoint(i)-SARofCurBar(i));
               SARofNextBar(i)=min([SARofNextBar(i) Low(i) Low(i-1)]);
            end
        end
        %空头情形下
        if Position(i-1)==-1
            %如果满足反转条件
            if High(i)>=SARofNextBar(i-1)
                Position(i)=1;
                Transition=1;
                SARofCurBar(i)=LowestPoint(i);
                HighestPoint(i)=High(i);
                LowestPoint(i)=Low(i);
                Af(i)=AfStep;
                SARofNextBar(i)=SARofCurBar(i)+Af(i)*(HighestPoint(i)-SARofCurBar(i));
                SARofNextBar(i)=min([SARofNextBar(i) Low(i) Low(i-1)]);
            %如果不满足反转条件
            else
                Position(i)=Position(i-1);
                SARofCurBar(i)=SARofNextBar(i-1);
                if LowestPoint(i)<LowestPoint(i-1) && Af(i-1)<AfLimit
                    if Af(i-1)+AfStep>AfLimit
                        Af(i)=AfLimit;
                    else
                        Af(i)=Af(i-1)+AfStep;
                    end
                else
                    Af(i)=Af(i-1);
                end
                SARofNextBar(i)=SARofCurBar(i)+Af(i)*(LowestPoint(i)-SARofCurBar(i));
                SARofNextBar(i)=max([SARofNextBar(i) High(i) High(i-1)]);
            end
        end
    end
end


end

