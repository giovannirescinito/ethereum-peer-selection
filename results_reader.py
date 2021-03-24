import xlsxwriter
import os
import json
from collections import defaultdict

workbook = xlsxwriter.Workbook('results.xlsx')
multiple_values = ['submission','tokenApproval','commitment','reveal']
    
for folder in os.listdir("results"):
    files = os.listdir("results/{0}".format(folder))
    if len(files) == 0:
        continue
    gas = dict()
    params = dict()
    par_list = []
    gas_list = []
    lengths = defaultdict(int)
    n = 0
    n_gas = 0
    completed_col = 0
    for file in os.listdir("results/"+folder):
        with open("results/"+folder+"/"+file) as f:
            data = json.load(f)
            gas[file] = data['gas']
            params[file] = data['params']
            if (data['params']['# of Proposals']>n):
                n = data['params']['# of Proposals']    
            if (len(data['gas'].keys())>n_gas):
                n_gas = len(data['gas'].keys())
                par_list = list(data['params'].keys())
                gas_list = list(data['gas'].keys())
                
    sheet = workbook.add_worksheet(folder)
    title1 = "Parameters"
    title2 = "Gas Consumption"
    sheet.write(0, 0, title1)
    sheet.write(0, len(par_list) + 1, title2)
    lengths[0] = len(title1)
    lengths[len(par_list)+1] = len(title2)
    index = 0
    for p in par_list:
        if p == 'Selection Completed':
            completed_col = index
        lengths[index] = max(lengths[index],len(str(p)))
        sheet.write(2, index, p)
        index+=1

    index+=2
    for g in gas_list:
        sheet.write(1,index,g)
        if g not in multiple_values:
            lengths[index] = max(lengths[index],len(str(g)))
            index+=1
        else:
            for i in range(n):
                sheet.write(2,index+i,i)
            index+=n
    num_cols = index
    row = 4
    col = 0

    for f in params.keys():
        for par in params[f].values():
            lengths[col] = max(lengths[col],len(str(par)))
            sheet.write(row, col, par)
            col+=1
        col +=2
        for g_k in gas[f].keys():
            g_v = gas[f][g_k]
            if g_k not in multiple_values:
                lengths[col] = max(lengths[col],len(str(g_v)))
                sheet.write(row, col, g_v)
                col+=1
            else:
                g_v = list(g_v.values())
                for i in range(len(g_v)):
                    lengths[col] = max(lengths[col],len(str(g_v[i])))
                    sheet.write(row, col, g_v[i])
                    col+=1
                col+=n-len(g_v)
        row+=1
        col = 0

    for i in range(num_cols):
        sheet.set_column(i,i,lengths[i]+1)

    format1 = workbook.add_format({'bg_color':'#008000'})
    format2 = workbook.add_format({'bg_color':'#FF0000'})
    sheet.conditional_format(4,completed_col,row-1,completed_col, {'type':'cell','criteria': '==','value':True,'format':format1})
    sheet.conditional_format(4,completed_col,row-1,completed_col, {'type':'cell','criteria': '==','value':False,'format':format2})

workbook.close()