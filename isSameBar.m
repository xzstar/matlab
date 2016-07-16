function isSameBarValue = isSameBar( date1,date2,time1,time2 )
%UNTITLED 此处显示有关此函数的摘要
%   此处显示详细说明
hour1 = floor(time1*100);
hour2 = floor(time2*100);
min1 = (mod(round(time1*10000),100));
min2 = (mod(round(time2*10000),100));

isSameBarValue = false;

if date1 == date2 && hour1 == hour2 && ((min1<30 && min2<30)||(min1>=30 && min2>=30)) 
    isSameBarValue = true;

end

