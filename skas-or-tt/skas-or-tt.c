/* 
skas_or_tt Copyright (C) 2003  
Jonathan Rosenbaum <freesource@users.sourceforge.net>

A program to check for the existence of the skas patch in the host
kernel and /proc/mm.  Basically borrowed/simplified from jdike's
process.c.  This is a good way to learn about clone() and ptrace().
 */

#include <stdio.h>
#include <unistd.h>
#include <errno.h>
#include <wait.h>
#include <sys/mman.h>  /* for mmap */
#include <sys/ptrace.h>
#include <sys/types.h>
#include <sched.h>  /* clone */
#define PTRACE_FAULTINFO 52
#define PAGE_SIZE 1024

int main(void)
{

	int n, pid, ret = 1, cmdline_value;
	void *stack;
 
	struct ptrace_faultinfo {
		int is_write;
		unsigned long addr;
	};
  

	struct ptrace_faultinfo fi;

	cmdline_value = host_cmdline();

	if ( cmdline_value == 1 ) {
		printf("Checking for the skas3 patch in the host...not found\nChecking for /proc/mm...not found\n");
		kill(pid, SIGSTOP);
		kill(pid, SIGKILL);
		return(0);
	}
	else if ( cmdline_value == 2 ) {
		printf("Checking for the skas3 patch in the host...found\nChecking for /proc/mm...found\n");
		kill(pid, SIGSTOP);
		kill(pid, SIGKILL);
		return(0);
	}

	printf("Checking for the skas3 patch in the host...");
	pid = start_ptraced_child(&stack);
	
	n = ptrace(PTRACE_FAULTINFO, pid, 0, &fi);
	if(n < 0){
		if(errno == EIO) 
			printf("not found\n");
		else printf("No (unexpected errno - %d)\n", errno);
		ret = 0;
	}
	else  printf("found\n");
  

	printf("Checking for /proc/mm...");
	if(access("/proc/mm", W_OK)){
		printf("not found\n");
		ret = 0;
	}
	else printf("found\n");

	kill(pid, SIGSTOP);
	kill(pid, SIGKILL);
	return(ret);

}


int host_cmdline (void) 
{

	char s[500]; /* should be the max cmdline size */
	FILE *f;
	char *tt = "mode=tt";
	char *skas = "mode=skas";
	char *ptt, *pskas;

	f = fopen("/proc/cmdline","r");
	if ( f == NULL ) {
	   printf("Error: unable to open /proc/cmdline for reading\n");
	   return(0);
   }
   
   if (fgets(s, sizeof s, f) != NULL) {

	   ptt = strstr(s, tt);
	   pskas = strstr(s, skas);
    
	   if ( ptt != NULL ) 
		   return(1);
	   else if ( pskas != NULL )
		   return(2);
	   else
		   return(0);
   }

   return(1);  /* safety default */

}


int os_getpid(void)
{
	return(getpid());
}

void os_stop_process(int pid)
{
	kill(pid, SIGSTOP);
}

void os_kill_process(int pid, int reap_child)
{
	kill(pid, SIGKILL);
	if(reap_child)
		waitpid(pid, NULL, 0);
		
}

static int ptrace_child(void *arg)
{
	int pid = os_getpid(); 

	if(ptrace(PTRACE_TRACEME, 0, 0, 0) < 0){
		perror("ptrace");
		os_kill_process(pid, 0);
	}

	os_stop_process(pid);
	_exit(os_getpid() == pid);

}


int start_ptraced_child(void **stack_out)
{
	void *stack;
	unsigned long sp;
	int pid, n, status;
	
	stack = mmap(NULL, PAGE_SIZE, PROT_READ | PROT_WRITE | PROT_EXEC,
		     MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
	if(stack == MAP_FAILED)
	        printf("check_ptrace : mmap failed, errno = %d", errno);
	sp = (unsigned long) stack + PAGE_SIZE - sizeof(void *);
	pid = clone(ptrace_child, (void *) sp, SIGCHLD, NULL);
	if(pid < 0) {
		printf("check_ptrace : clone failed, errno = %d\n", errno);
		exit(0);
	}
	n = waitpid(pid, &status, WUNTRACED);
	if(n < 0) {
		printf("check_ptrace : wait failed, errno = %d\n", errno);
		exit(0);
	}
	if(!WIFSTOPPED(status) || (WSTOPSIG(status) != SIGSTOP)) {
		printf("check_ptrace : expected SIGSTOP, got status = %d\n",
		      status);
		exit(0);
	}
	*stack_out = stack;
	return(pid);
}


/*
 * Overrides for Emacs so that we follow Linus's tabbing style.
 * Emacs will notice this stuff at the end of the file and automatically
 * adjust the settings for this buffer only.  This must remain at the end
 * of the file.
 * ---------------------------------------------------------------------------
 * Local variables:
 * c-file-style: "linux"
 * End:
 */
