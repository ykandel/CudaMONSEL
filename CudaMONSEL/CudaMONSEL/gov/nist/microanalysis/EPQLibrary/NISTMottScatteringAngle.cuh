// file: gov\nist\microanalysis\EPQLibrary\NISTMottScatteringAngle.cuh

#ifndef _NIST_MOTT_SCATTERING_ANGLE_CUH_
#define _NIST_MOTT_SCATTERING_ANGLE_CUH_

#include "gov\nist\microanalysis\NISTMonte\Declarations.cuh"
#include "gov\nist\microanalysis\EPQLibrary\RandomizedScatter.cuh"
#include "gov\nist\microanalysis\EPQLibrary\RandomizedScatterFactory.cuh"

namespace NISTMottScatteringAngle
{
   extern const int SPWEM_LEN;
   extern const int X1_LEN;
   extern const double DL50;
   extern const double PARAM;

   class NISTMottScatteringAngle : public RandomizedScatterT
   {
   public:
      __host__ __device__ explicit NISTMottScatteringAngle(const ElementT& elm);

      StringT toString() const;

      const ElementT& getElement() const override;
      double totalCrossSection(const double) const override;
      double randomScatteringAngle(const double) const override;

      __host__ __device__ const VectorXf& getSpwem() const;
      __host__ __device__ const MatrixXf& getX1() const;

      __device__ void copySpwem(float *, unsigned int);
      __device__ void copyX1j(unsigned int, float *, unsigned int);

   private:
      void loadData(int an);

      const ElementT& mElement;
      VectorXf mSpwem;
      MatrixXf mX1;
      const ScreenedRutherfordScatteringAngleT& mRutherford;
   };

   //extern const double MAX_NISTMOTT;

   class NISTMottRandomizedScatterFactory : public RandomizedScatterFactoryT
   {
   public:
      NISTMottRandomizedScatterFactory();

      const RandomizedScatterT& get(const ElementT& elm) const override;

   protected:
      void initializeDefaultStrategy() override;
   };

   const NISTMottScatteringAngle* mScatter[];

   extern const RandomizedScatterFactoryT& Factory;

   __host__ __device__ extern const NISTMottScatteringAngle& getNISTMSA(int an);

   extern void init();
   extern __global__ void initCuda();
   extern void copyDataToCuda();
}

#endif