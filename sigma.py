import subprocess
def username():
    print("---------------------- USERNAME--> root --------------------------------------")
    pasd=input("Enter your password for compute node root user ---> ")
    return (pasd)

def adapt():
    adpt=int(input("please enter the host only network adapter name of master node ---> "))
    return (adpt)

def adapt2():
    adapt2=int(input("please enter the network adapter name of compute nodes ---> "))
    return (adapt2)

with open(r"mac_file",'r') as fp:
    mac_c=len(fp.readlines())
with open(r"ip_file",'r') as fp:
    ip_c=len(fp.readlines())

def nfsfun():
    nfs='n'
    nfs=input("DO YOU HAVE A EXTERNAL DISK CONNECTED MASTER NODE FOR NFS --->").lower()
    if nfs=="yes" or nfs=="y":
            subprocess.run(['bash','nfs/nfs.sh' ])
    return (nfs)

def bootinput(password,adapter,adapter2,nfs,mac_c):
    print("\n 1.STATE LESS\n 2.STATE FULL\n")
    inp=int(input("ENTER THE BOOTING OPTION ---> "))

    if inp==1:  # $1--adapter $2--password $3--mac_c--mac_file
        subprocess.run([f'bash','xcat_stateless/xcat_stateless.sh',f'{adapter}',f'{password}',f'{mac_c}',f'{nfs}'])
        ready_nodes="no"
        while ready_nodes != "yes":
            ready_nodes=input("\n   START THE NODES ""YES OR NO ---> ")
        # $1-- mac_c --mac_file $2-- hostonly network adapter of compute nodes
        subprocess.run([f'bash','xcat_stateless/.sh',f'{mac_c}',f'{adapter2}'])

    elif inp==2:
        subprocess.run([f'bash','xcat_statefull/xcat_statefull.sh',f'{adapter}',f'{password}',f'{mac_c}',f'{nfs}'])
        ready_nodes="no"
        while ready_nodes != "yes":
            
            ready_nodes=input("\n   START THE NODES ""YES OR NO ---> ")
        #script 2 # $1--mac_c--mac_file #$2-- hostonly network adpater of compute nodes
        subprocess.run([f'bash','xcat_statefull/xcat_statefull_nagios_installation.sh',f'{mac_c}',f'{adapter2}'])
        subprocess.run([f'bash','xcat_statefull/xcat_statefull_slurm_installation.sh',f'{mac_c}',f'{adapter2}'])
    else:
        print("\n PLSEASE SELECT THE OPTION........\n")
def main():
    if mac_c==ip_c:
        password=username()
        adapter=adapt()
        adapter2=adapt2()
        nfs=nfsfun()
        bootinput(password,adapter,adapter2,nfs,mac_c)
    else:
        print("!!!! CHECK IP OR MAC FILE !!!!")   
main()