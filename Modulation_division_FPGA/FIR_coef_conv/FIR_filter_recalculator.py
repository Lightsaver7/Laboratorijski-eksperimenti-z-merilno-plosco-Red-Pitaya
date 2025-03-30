import math
import numpy as np


def convert_coef(coef_arr, coef_bits, low_pass=False):
    """Convert filter coeficients to integer values with maximum "coef_bits" bits.
    """
    
    if low_pass:
        filt_sum = 2*np.sum(coef_arr) - coef_arr[-1]
        print(filt_sum)
        multiplier = pow(2, coef_bits)/filt_sum
        new_coef_arr = np.rint(np.multiply(coef_arr, multiplier)).astype(int)
        filt_sum = 2*np.sum(new_coef_arr) - new_coef_arr[-1]
    else:
        
        max_value = np.max(np.absolute(np.array(coef_arr)))
        multiplier = (pow(2, coef_bits)/2 -1)/max_value
        new_coef_arr = np.rint(np.multiply(coef_arr, multiplier)).astype(int)
        filt_sum = 2*np.sum(new_coef_arr) - new_coef_arr[5]

    print(multiplier)
    print(new_coef_arr)
    print(filt_sum)
    print("\n")
    return new_coef_arr


coef_low = [
    0.123642574470133978503660898695670766756,
    0.076439272206744859894378407716430956498,
    0.092976080514154346712274445962975732982,
    0.106348480961931557420285798798431642354,
    0.114819991146986322139156300181639380753,
    0.117786188756463294780019168683793395758,
    0.114819991146986322139156300181639380753,
    0.106348480961931557420285798798431642354,
    0.092976080514154346712274445962975732982,
    0.076439272206744859894378407716430956498,
    0.123642574470133978503660898695670766756]


coef_high = [-22, -32, -51, -66, -79, 511, -79, -66, -51, -32, -22]
coef_bs = [109, 57, 22, -38, -95, 511, -95, -38, 22, 57, 109]
coef_bs2 = [194, -42, -42, -80, -80, 511, -80, -80, -42, -42, 194]
coef_bp = [-360, -132, -21, 151, 306, 368, 306, 151, -21, -132, -360]
coef_low = [110, 69, 83, 95, 102, 105, 102, 95, 83, 69, 110]        # prof

coef_bp = [
    -0.200057825255776422501696742983767762780,
    -0.073463001120697937751380379722832003608,
    -0.011548756267275256046089815242794429651,
     0.083871804809400249403061877728760009632,
     0.170112125542878633854826375682023353875,
     0.204610402957770554088767767098033800721,
     0.170112125542878633854826375682023353875,
     0.083871804809400249403061877728760009632,
    -0.011548756267275256046089815242794429651,
    -0.073463001120697937751380379722832003608,
    -0.200057825255776422501696742983767762780
]



# sum_low = np.sum(coef_low)
# sum_high = np.sum(coef_high)
# sum_bp = np.sum(coef_bp)
# sum_bs = np.sum(coef_bs)
# print(f"low: {sum_low}, high: {sum_high}, bandpass: {sum_bp}, bandstop: {sum_bs}\n")
# 
# fact_low = 1024/sum_low
# fact_high = 8/sum_high
# fact_bp = 256/sum_bp
# fact_bs = 512/sum_bs
# 
# coef_low = np.rint(np.multiply(coef_low, fact_low)).astype(int)
# coef_high = np.rint(np.multiply(coef_high, fact_high)).astype(int)
# coef_bp = np.rint(np.multiply(coef_bp, fact_bp)).astype(int)
# coef_bs = np.rint(np.multiply(coef_bs, fact_bs)).astype(int)
# print(f"low: {coef_low}, high: {coef_high}, bandpass: {coef_bp}, bandstop: {coef_bs}\n")
# sum_low = np.sum(coef_low)
# sum_high = np.sum(coef_high)
# sum_bp = np.sum(coef_bp)
# sum_bs = np.sum(coef_bs)
# 
# print(f"low: {sum_low}, high: {sum_high}, bandpass: {sum_bp}, bandstop: {sum_bs}\n")



coef_hp = [
    -0.002814215258012777928775527414018142736,
     0.029835958543833349110308006402192404494,
     0.043486072905060596527349048301402945071,
    -0.069506213807174269114774745048634940758,
    -0.290671857647047671147078062858781777322,
     0.59010651097775301821002358337864279747]

new_coef = convert_coef(coef_hp, 10)


coef_lp = [3, -3, -26, 8, 151, 246]


new_coef = convert_coef(coef_lp, 10, low_pass=True)


coef_lp = [      -0.086570480457125564832665531866950914264,
     -0.033075405185217392201035835341826896183,
      0.095877133423222252184281444442603969947,
    -0.175180130535121131307718655989447142929,
      0.240693347033903326526171895238803699613,
      0.733962783201024149271063379273982718587]

sum_coef = np.sum(coef_lp)
print(sum_coef)
new_coef = convert_coef(coef_lp, 10, low_pass=True)

coef_lp = [ 0.020439555934429486788728169699425052386,
            -0.023385262611667453208630362837538996246,
            -0.075880624081889544441104078487114747986,
             0.030169993393586815033646786332610645331,
             0.305441068147460026427353341205161996186,
             0.4632318958995147450963258961564861238]

sum_coef = np.sum(coef_lp)
print(sum_coef)
new_coef = convert_coef(coef_lp, 10, low_pass=True)



coef_hp = [
      -0.192564573032951519282462982118886429816,
     -0.049470618539179514461245901202346431091,
      -0.053788375443810945708555948385765077546,
    -0.057216864512822304678074658568220911548,
     -0.059164767486266540974515493189755943604,
      0.940303619630167619725114036555169150233]

new_coef = convert_coef(coef_hp, 10)

