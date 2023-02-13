#!/bin/env python

import pygrib
from numpy import ma
import xarray as xr
import sys

filename=sys.argv[1]
gribs=pygrib.open(filename)

with open(filename+'.fix','wb') as grbout:
    for n,grib in enumerate(gribs):
        if grib['shortName']=='pp1d':
            data=grib['values']
            #print(n+1,data.min(),data.max(),end=' ')
            data.mask=ma.mask_or(data.mask,data<0)
            data.mask=ma.mask_or(data.mask,data>30)
            #print(data.min(),data.max())
            grib['values']=data.filled()
        elif (grib['shortName']=='10u' or grib['shortName']=='10v'):        
            # chech 10m u,v should be in -100 to 100 range
            data=grib['values']
            data.mask=ma.mask_or(data.mask,data<-100)
            data.mask=ma.mask_or(data.mask,data>100)
            grib['values']=data.filled()
        msg=grib.tostring()
        grbout.write(msg)

data1=xr.open_dataset(filename,decode_times=True,engine='cfgrib')
data2=xr.open_dataset(filename+'.fix',decode_times=True,engine='cfgrib')

with open('data_range.txt','w') as mfile:
    mfile.write(f'{filename}\n')
    mfile.write(f'{data1.u10.min().round().values} <= u10 <= {data1.u10.max().round().values}\n')
    mfile.write(f'{data1.v10.min().round().values} <= v10 <= {data1.v10.max().round().values}\n')
    mfile.write(f'{data1.swh.min().round().values} <= swh <= {data1.swh.max().round().values}\n')
    mfile.write(f'{data1.pp1d.min().round().values} <= pp1d <= {data1.pp1d.max().round().values}\n')
    mfile.write(f'{data1.mwd.min().round().values} <= mwd <= {data1.mwd.max().round().values}\n')
    mfile.write('     \n')
    mfile.write(f'{filename}.fix\n')
    mfile.write(f'{data2.u10.min().round().values} <= u10 <= {data2.u10.max().round().values}\n')
    mfile.write(f'{data2.v10.min().round().values} <= v10 <= {data2.v10.max().round().values}\n')
    mfile.write(f'{data2.swh.min().round().values} <= swh <= {data2.swh.max().round().values}\n')
    mfile.write(f'{data2.pp1d.min().round().values} <= pp1d <= {data2.pp1d.max().round().values}\n')
    mfile.write(f'{data2.mwd.min().round().values} <= mwd <= {data2.mwd.max().round().values}\n')
