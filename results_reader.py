import xlsxwriter
import os
import json
import re
from collections import defaultdict
from xlsxwriter.utility import xl_rowcol_to_cell

workbook = xlsxwriter.Workbook('results.xlsx')
aggregated_results = ['Total cost (users+algorithm)','Total algorithm cost','Deployment','Partitionining & Assignment','Selection Phase','Submission per user','Token approval per user','Commitment per user','Reveal per user','Total per user']
multiple_values = ['submission','tokenApproval','commitment','reveal']
deployment_list = ['deployment','deploymentToken','finalization']
selection_list = ['selection','endSelection','quotas','allocations','winners','allocationSelected','scoreMatrix']

def list_to_cells(s,row,col,indexes,sheet):
    if len(indexes[s])==0:
        return col+1
    lst = ''
    for i in indexes[s]:
        lst+= i + ','
    lst = lst[:-1]
    sheet.write_formula(row,col,'=SUM({0})'.format(lst))
    return col+1

def per_user(s,row,col, indexes,sheet):
    if len(indexes[s])==0:
        return col+3
    e0 = indexes[s]['1']
    e1 = indexes[s]['n']
    sheet.write_formula(row,col,'={0}'.format(e0))        
    sheet.write_formula(row,col+1,'={0}'.format(e1))  
    sheet.write_formula(row,col+2,'=AVERAGE({0}:{1})'.format(e0,e1))  
    col +=3
    return col

def total_user(row,sub,sel,sheet):
    lst = ''
    for _ in range(4):
        lst+= xl_rowcol_to_cell(row,sub) + ','
        sub+=3
    lst = lst[:-1]
    sheet.write_formula(row,sel,'=SUM({0})'.format(lst))
    return      


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
    title2 = "Gas Consumption Recap"
    title3 = "Gas Consumption Detail"

    sheet.write(0, 0, title1)
    lengths[0] = len(title1)
    
    index = 0
    for p in par_list:
        if p == 'Selection Completed':
            completed_col = index
        lengths[index] = max(lengths[index],len(str(p)))
        sheet.write(2, index, p)
        index+=1

    index+=2
    sheet.write(0, index, title2)
    lengths[index] = len(title2)
    index+=1
    agg_res_start = index
    
    users_str = ['User #1', 'User #n', 'Average']
    for i in aggregated_results:
        sheet.write(1, index, i)
        lengths[index] = max(lengths[index],len(str(i)))
        if re.search('per user',i) is not None:
            for ii in range(3):
                lengths[index] = max(lengths[index],len(str(users_str[ii])))
                sheet.write(2, index, users_str[ii])
                index+=1
        else:
            index+=1
    index+=2
    gas_start = index
    sheet.write(0,gas_start-1 , title3)
    lengths[gas_start-1] = len(title3)

    for g in gas_list:
        if g == 'total':
            continue
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
        col = gas_start
        indexes = {'deployment':[],'partition':[],'submission':{},'tokenApproval':{},'commitment':{},'reveal':{},'algorithm':[],'selection':[]}
        for g_k in gas[f].keys():
            g_v = gas[f][g_k]
            if g_k in ['partitioning','assignment']:
                indexes['partition'].append(xl_rowcol_to_cell(row,col))
            elif g_k in deployment_list:
                indexes['deployment'].append(xl_rowcol_to_cell(row,col))
            elif g_k in selection_list:
                indexes['selection'].append(xl_rowcol_to_cell(row,col))
            elif g_k == 'total':
                continue
            
            if g_k not in multiple_values:
                indexes['algorithm'].append(xl_rowcol_to_cell(row,col))
                lengths[col] = max(lengths[col],len(str(g_v)))
                sheet.write(row, col, g_v)
                col+=1
            else:
                g_v = list(g_v.values())
                indexes[g_k]['1'] = xl_rowcol_to_cell(row,col)
                indexes[g_k]['n'] = xl_rowcol_to_cell(row,col + len(g_v) -1)
                for i in range(len(g_v)):
                    lengths[col] = max(lengths[col],len(str(g_v[i])))
                    sheet.write(row, col, g_v[i])
                    col+=1
                col+=n-len(g_v)

        sel_col = agg_res_start
        # Total Cost
        sheet.write_formula(row,sel_col,'=SUM({0}:{1})'.format(xl_rowcol_to_cell(row,gas_start),xl_rowcol_to_cell(row,col-1)))
        sel_col+=1
        # Total algorithm cost
        sel_col = list_to_cells('algorithm',row,sel_col,indexes,sheet)
        # Total deployment cost
        sel_col = list_to_cells('deployment',row,sel_col,indexes,sheet)
        # Partitioning/Assignment cost
        sel_col = list_to_cells('partition',row,sel_col,indexes,sheet)
        # Selection cost        
        sel_col = list_to_cells('selection',row,sel_col,indexes,sheet)
        # Submission cost
        sub_col = sel_col
        sel_col = per_user('submission',row,sel_col,indexes,sheet)
        # Token Approval cost
        sel_col = per_user('tokenApproval',row,sel_col,indexes,sheet)
        # Commitment cost
        sel_col = per_user('commitment',row,sel_col,indexes,sheet)
        # Reveal cost
        sel_col = per_user('reveal',row,sel_col,indexes,sheet)
        # Total per user
        for i in range(3):
            total_user(row,sub_col+i,sel_col+i,sheet)
 
        row+=1
        col = 0

        
    for i in range(num_cols):
        sheet.set_column(i,i,lengths[i])

    format1 = workbook.add_format({'bg_color':'#008000'})
    format2 = workbook.add_format({'bg_color':'#FF0000'})
    sheet.conditional_format(4,completed_col,row-1,completed_col, {'type':'cell','criteria': '==','value':True,'format':format1})
    sheet.conditional_format(4,completed_col,row-1,completed_col, {'type':'cell','criteria': '==','value':False,'format':format2})

workbook.close()