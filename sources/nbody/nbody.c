/**
 * Copyright (C) 2010 Erik Rainey
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#ifdef _MSC_VER
#include <CL/cl.h>
#else
#include <OpenCL/opencl.h>
#endif
#include <kernel_nbody.h>
#include <clmath.h>
#include <clenvironment.h>

#define CL_OPTIONS  ("-I/Users/emrainey/Source/OpenCL/include")

void notify(cl_program program, void *arg)
{
    printf("Program %p Arg %p\n",program, arg);
}

cl_int distance(cl_environment_t *pEnv,
                cl_float4 *p, 
				cl_float *d,
                cl_uint numPoints)
{
	cl_uint n  = sizeof(float) * numPoints;
	cl_uint n4 = sizeof(cl_float4) * numPoints;
    cl_kernel_param_t params[] = {
        {n4,p,NULL,CL_MEM_READ_ONLY},
        {n ,d,NULL,CL_MEM_WRITE_ONLY},
    };
    cl_kernel_call_t call = {
		"kernel_magnitude",
		params, dimof(params),
		1, 
		{0,0,0},
		{numPoints, 0, 0},
		{1,1,1},
		CL_SUCCESS, 0,0,0
	};
    return clCallKernel(pEnv, &call);
}

cl_int nbodies(cl_environment_t *pEnv,
			   cl_float *ms,  
			   cl_float *m,
               cl_float4 *a,
               cl_float4 *v,
               cl_float4 *p,
               cl_float *t, 
		       cl_float *d,   
		       cl_float *g,
               size_t numBodies)
{
	cl_uint n = sizeof(cl_float)*numBodies;
	cl_uint n4 = sizeof(cl_float4)*numBodies;
	cl_kernel_param_t params[] = {
		{n, ms, NULL, CL_MEM_READ_WRITE},
		{n,  m, NULL, CL_MEM_READ_ONLY},
		{n4, a, NULL, CL_MEM_READ_WRITE},
		{n4, v, NULL, CL_MEM_READ_WRITE},
		{n4, p, NULL, CL_MEM_READ_WRITE},
		{n,  t, NULL, CL_MEM_READ_ONLY},
		{n,  d, NULL, CL_MEM_READ_WRITE},
		{n,  g, NULL, CL_MEM_READ_WRITE},		
	};
	cl_kernel_call_t call = {
		"kernel_nbody",
		params, dimof(params),
		1, 
		{0,0,0},
		{numBodies, 0, 0},
		{1,1,1},
		CL_SUCCESS,0,0,0
	};
	return clCallKernel(pEnv, &call);
}

int main(int argc, char *argv[])
{
    const size_t numBodies = 10;
    float *m     = cl_malloc_array(float, numBodies);
	float *ms    = cl_malloc_array(float, numBodies);
    float *d     = cl_malloc_array(float, numBodies);
    float *g     = cl_malloc_array(float, numBodies);
    float *t     = cl_malloc_array(float, numBodies);
    cl_float4 *a = cl_malloc_array(cl_float4, numBodies);
    cl_float4 *v = cl_malloc_array(cl_float4, numBodies);
    cl_float4 *p = cl_malloc_array(cl_float4, numBodies);

    time_t start, diff;
    clock_t c_start, c_diff;

    // cl_environment_t *pEnv = clCreateEnvironment(KDIR"kernel_nbody.cl",1,notify, CL_OPTIONS);
	cl_environment_t *pEnv = clCreateEnvironmentFromBins(&gKernelBins, notify, CL_OPTIONS);
	if (pEnv)
    {
        cl_uint i = 0;
        for (i = 0; i < numBodies; i++)
        {
            m[i] = frand() * ipow(10,rrand(4,27)); // masses should be 10^4 - 10^27 (Earth heavy)
            frand4(a[i], 1, 8);
			frand4(v[i], 1, 9);
			frand4(p[i], 4, 8);
            t[i] = 0.001; // 1 millisecond.
            d[i] = 0.00; // this will be initialized in the kernel
            g[i] = 0.00; // this will be initialized in the kernel
        }

        start = time(NULL);
        c_start = clock();
        nbodies(pEnv, ms, m, a, v, p, t, d, g, numBodies);
        distance(pEnv, p, d, numBodies);
        c_diff = clock() - c_start;
        diff = time(NULL) - start;
        printf("Constant Version Ran in %lu seconds (%lu ticks)\n", diff, c_diff);

//#ifdef CL_DEBUG
        for (i = 0; i < numBodies; i++)
        {
            printf("[%6u] p={%.2lf,%.2lf,%.2lf} v={%.2lf,%.2lf,%.2lf} a={%.2lf,%.2lf,%.2lf} d=%lf g=%lf\n", i,
                    p[i][0], p[i][1], p[i][2],
                    v[i][0], v[i][1], v[i][2],
                    a[i][0], a[i][1], a[i][2], d[i], g[i]);
        }
//#endif
        clDeleteEnvironment(pEnv);
		cl_free(g);
		cl_free(d);
		cl_free(t);
		cl_free(m);
		cl_free(v); 
		cl_free(a);
		cl_free(p);
    }
    return 0;
}

