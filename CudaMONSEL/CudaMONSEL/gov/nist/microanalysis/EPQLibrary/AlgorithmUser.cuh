#ifndef _ALGORITHM_USER_CUH_
#define _ALGORITHM_USER_CUH_

#include "gov\nist\microanalysis\NISTMonte\Declarations.cuh"

namespace AlgorithmUser
{
   class AlgorithmUser
   {
   protected:
      AlgorithmUser();

      virtual void initializeDefaultStrategy() = 0;

   //private:
      //Strategy mLocalOverride = null;
   };

   // Strategy mGlobalOverride = null;

   extern const EdgeEnergyT& sDefaultEdgeEnergy;
   //static TransitionEnergy sDefaultTransitionEnergy = null;
   //static MassAbsorptionCoefficient sDefaultMAC = null;
   //static FluorescenceYieldMean sDefaultFluorescenceYieldMean = null;
   //static FluorescenceYield sDefaultFluorescenceYield = null;
   //static BetheElectronEnergyLoss sDefaultBetheEnergyLoss = null;
   //static Bremsstrahlung.AngularDistribution sDefaultAngularDistribution = null;
   //static CorrectionAlgorithm sDefaultCorrectionAlgorithm = null;

   const EdgeEnergyT& getDefaultEdgeEnergy();
}

#endif