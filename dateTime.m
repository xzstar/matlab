function [DateTimeValue,DateTimeFloat] = dateTime( Date,Hour )
%UNTITLED2 此处显示有关此函数的摘要
%   此处显示详细说明
DateTimeValue=zeros(length(Date),1);
DateTimeFloat=zeros(length(Date),1);
for i=1:length(Date)
    year = floor(Date(i)/10000);
    month = floor(mod(Date(i),10000)/100);
    day = floor(mod(Date(i),100));
    h = fix(Hour(i)*100);
    m = mod(round(Hour(i)*10000),100);
    DateTimeValue(i)= datenum(year,month,day,h,m,0);
    DateTimeFloat(i)= Date(i)+Hour(i);
end

end

